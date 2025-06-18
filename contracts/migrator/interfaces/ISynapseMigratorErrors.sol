// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ISynapseMigratorErrors {
    error SM__SameAddress();
    error SM__TokenPairAlreadyAdded();
    error SM__TokenPairNotAdded();
    error SM__ZeroAddress();
    error SM__ZeroAmount();
}
