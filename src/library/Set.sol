// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

struct Set {
    address[] values;
    mapping(address => bool) has;
}

library SetLib {
    function add(Set storage set, address value) public {
        if (set.has[value] == false) {
            set.values.push(value);
            set.has[value] = true;
        }
    }
}
