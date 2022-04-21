// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.4;

import "../interfaces/IHodlAuthority.sol";

abstract contract HodlAccessControlled {
    event AuthorityUpdated(IHodlAuthority indexed authority);
    
    string private UNAUTHORIZED = "UNAUTHORIZED";

    IHodlAuthority public authority;

    constructor(IHodlAuthority _authority) {
        require(address(_authority) != address(0), "ZeroAddress");
        authority = _authority;
        emit AuthorityUpdated(_authority);
    }

    modifier onlyGovernor() {
        require(msg.sender == authority.governor(), UNAUTHORIZED);
        _;
    }
    
    modifier onlyGovernorPolicy() {
        require(msg.sender == authority.governor() || msg.sender == authority.policy(), UNAUTHORIZED);
        _;
    }

    modifier onlyGuardian() {
        require(msg.sender == authority.guardian(), UNAUTHORIZED);
        _;
    }

    modifier onlyVault() {
        require(msg.sender == authority.vault(), UNAUTHORIZED);
        _;
    }

    function setAuthority(IHodlAuthority _newAuthority) external onlyGovernor {
        require(address(_newAuthority) != address(0), "ZeroAddress");
        authority = _newAuthority;
        emit AuthorityUpdated(_newAuthority);
    }
}
