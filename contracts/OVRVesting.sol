// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol"; // Includes Intialize, Context
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OVRVesting is AccessControl {
    constructor(IERC20 _token) {
        token = _token;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint256 private constant vstart = 1661983200; // Thu Sep 01 2022 00:00:00 GMT+0200
    uint256 public constant vcliff = 1661983200; // Thu Sep 01 2022 00:00:00 GMT+0200
    uint256 public constant vend = 1725141600; // Sun Sep 01 2024 00:00:00 GMT+0200
    uint256 public constant vinstallmentLength = 3600; // 60 min

    // Vesting grant for a specific holder.
    struct Grant {
        uint256 value;
        uint256 start;
        uint256 cliff;
        uint256 end;
        uint256 installmentLength; // In seconds.
        uint256 transferred;
        bool revocable;
    }

    // Holder to grant information mapping.
    mapping(address => Grant) public grants;

    // Total tokens available for vesting.
    uint256 public totalVesting;

    event NewGrant(address indexed _from, address indexed _to, uint256 _value);

    event TokensUnlocked(address indexed _to, uint256 _value);

    event GrantRevoked(address indexed _holder, uint256 _refund);

    /**
     * @dev Unlock vested tokens and transfer them to their holder.
     */
    function unlockVestedTokens() external {
        Grant memory grant_ = grants[_msgSender()];

        // Require that the grant is not empty.
        require(grant_.value != 0);

        // Get the total amount of vested tokens, according to grant.
        uint256 vested = calculateVestedTokens(grant_, block.timestamp);

        if (vested == 0) {
            return;
        }

        // Make sure the holder doesn't transfer more than what he already has.

        uint256 transferable = vested.sub(grant_.transferred);

        if (transferable == 0) {
            return;
        }

        console.log("vested", vested);
        console.log("transferable_BEFORE", transferable);
        console.log("grant_.transferred_BEFORE", grant_.transferred);
        console.log("totalVesting_BEFORE", totalVesting);

        // Update transferred and total vesting amount, then transfer remaining vested funds to holder.
        grant_.transferred = grant_.transferred.add(transferable);
        totalVesting = totalVesting.sub(transferable); // problema qui
        token.transfer(_msgSender(), transferable);

        console.log("transferable_AFTER", transferable);
        console.log("grant_.transferred_AFTER", grant_.transferred);
        console.log("totalVesting_AFTER", totalVesting);
        emit TokensUnlocked(_msgSender(), transferable);
    }

    /**
     * @dev Grant tokens to a specified address.
     * @param _to address The holder address.
     * @param _value uint256 The amount of tokens to be granted.
     * @param _revocable bool Whether the grant is revocable or not.
     */
    function granting(
        address _to,
        uint256 _value,
        bool _revocable
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_to != address(0));

        // Don't allow holder to be this contract.
        require(_to != address(this));

        require(_value > 0);

        // Require that every holder can be granted tokens only once.
        require(grants[_to].value == 0);

        // Assign a new grant.
        grants[_to] = Grant({
            value: _value,
            start: vstart,
            cliff: vcliff,
            end: vend,
            installmentLength: vinstallmentLength,
            transferred: 0,
            revocable: _revocable
        });

        // Since tokens have been granted, increase the total amount of vesting.
        totalVesting = totalVesting.add(_value);

        emit NewGrant(_msgSender(), _to, _value);
    }

    /**
     * @dev Calculate the total amount of vested tokens of a holder at a given time.
     * @param _holder address The address of the holder.
     * @param _time uint256 The specific time to calculate against.
     * @return a uint256 Representing a holder's total amount of vested tokens.
     */
    function vestedTokens(address _holder, uint256 _time)
        public
        view
        returns (uint256)
    {
        Grant memory grant_ = grants[_holder];
        if (grant_.value == 0) {
            return 0;
        }
        return calculateVestedTokens(grant_, _time);
    }

    /**
     * @dev Revoke the grant of tokens of a specifed address.
     * @param _holder The address which will have its tokens revoked.
     */
    function revoke(address _holder) public onlyRole(DEFAULT_ADMIN_ROLE) {
        Grant memory grant_ = grants[_holder];

        // Grant must be revocable.
        require(grant_.revocable);

        // Calculate amount of remaining tokens that are still available (i.e. not yet vested) to be returned to owner.
        uint256 vested = calculateVestedTokens(grant_, block.timestamp);
        uint256 notTransferredInstallment = vested.sub(grant_.transferred);
        uint256 refund = grant_.value.sub(vested);

        //Update of transferred not necessary due to deletion of the grant in the following step.

        // Remove grant information.
        delete grants[_holder];

        // Update total vesting amount and transfer previously calculated tokens to owner.
        totalVesting = totalVesting.sub(refund).sub(notTransferredInstallment);

        // Transfer vested amount that was not yet transferred to _holder.
        token.transfer(_holder, notTransferredInstallment);
        emit TokensUnlocked(_holder, notTransferredInstallment);
        token.transfer(_msgSender(), refund);
        emit TokensUnlocked(_msgSender(), refund);
        emit GrantRevoked(_holder, refund);
    }

    /**
     * @dev Revoke all the grants of tokens.
     * @param _vault The address which will receive the tokens.
     */

    function revokeAll(address _vault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 transferable = token.balanceOf(address(this));
        token.transfer(_vault, transferable);
    }

    /**
     * @dev Calculate amount of vested tokens at a specifc time.
     * @param _grant Grant The vesting grant.
     * @param _time uint256 The time to be checked
     * @return a uint256 Representing the amount of vested tokens of a specific grant.
     */
    function calculateVestedTokens(Grant memory _grant, uint256 _time)
        public
        view
        returns (uint256)
    {
        // If we're before the cliff, then nothing is vested.
        if (_time < _grant.cliff) {
            return 0;
        }

        // If we're after the end of the vesting period - everything is vested;
        if (_time >= _grant.end) {
            return _grant.value;
        }

        // Calculate amount of installments past until now.
        // NOTE result gets floored because of integer division.
        uint256 installmentsPast = _time.sub(_grant.start).div(
            _grant.installmentLength
        );
        console.log("calculateVestedTokens._grant.value", _grant.value);
        console.log("calculateVestedTokens._grant.start", _grant.start);
        console.log("calculateVestedTokens.installmentsPast", installmentsPast);

        // Calculate amount of days in entire vesting period.
        uint256 vestingDays = _grant.end.sub(_grant.start);

        console.log("calculateVestedTokens.vestingDays", vestingDays);

        // Calculate and return installments that have passed according to vesting days that have passed.
        return
            _grant
                .value
                .mul(installmentsPast.mul(_grant.installmentLength))
                .div(vestingDays);
    }

    function addAdminRole(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(DEFAULT_ADMIN_ROLE, _account);
    }

    function removeAdminRole(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(DEFAULT_ADMIN_ROLE, _account);
    }
}
