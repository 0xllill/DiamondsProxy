// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IDiamondCut } from "../interfaces/IDiamondCut.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import "hardhat/console.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

contract DiamondCutFacet is IDiamondCut {
    struct LogCut {
        mapping(uint => FacetCut[]) facetCut;
        uint logSize; // number of facets in the array
    }
    bytes32 constant MODIFICATION_STORAGE_POSITION = keccak256("diamond.standard.modification.storage");
    bytes32 constant LOG_CUT_POSITION = keccak256("diamond.log.cut.position");
    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        LibDiamond.enforceIsContractOwner();
        log(_diamondCut);
        LibDiamond.diamondCut(_diamondCut, _init, _calldata); 
    }

    function log(FacetCut[] calldata _diamondcut) private {
        for (uint i=0;i<_diamondcut.length;i++){
            FacetCut memory cut;
            if (_diamondcut[i].action == FacetCutAction.Add)
            {
                cut.action = FacetCutAction.Remove;
                cut.facetAddress = address(0);
                cut.functionSelectors = _diamondcut[i].functionSelectors;
                logCuts().facetCut[logCuts().logSize].push(cut);
            }
            if (_diamondcut[i].action == FacetCutAction.Remove) { 
                for (uint z=0;z<_diamondcut[i].functionSelectors.length;z++){
                    FacetCut memory cut2;
                    cut2.action = FacetCutAction.Add;
                    LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
                    address oldFacetAddress = ds.selectorToFacetAndPosition[_diamondcut[i].functionSelectors[z]].facetAddress;
                    cut2.facetAddress = oldFacetAddress;
                    bytes4 selector = _diamondcut[i].functionSelectors[z];
                    bytes4[] memory array_ = new bytes4[](1);
                    array_[0] = selector; 
                    cut2.functionSelectors = array_;
                    logCuts().facetCut[logCuts().logSize].push(cut2);
                }   
            }
            if (_diamondcut[i].action == FacetCutAction.Replace) {
                for (uint z=0;z<_diamondcut[i].functionSelectors.length;z++){                    
                    FacetCut memory cut2;
                    cut2.action = FacetCutAction.Replace;
                    LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
                    address oldFacetAddress = ds.selectorToFacetAndPosition[_diamondcut[i].functionSelectors[z]].facetAddress;
                    cut2.facetAddress = oldFacetAddress;
                    bytes4 selector = _diamondcut[i].functionSelectors[z];
                    bytes4[] memory array_ = new bytes4[](1);
                    array_[0] = selector; 
                    cut2.functionSelectors = array_;
                    logCuts().facetCut[logCuts().logSize].push(cut2);
                }
            }
            logCuts().logSize++;           
        }
    }
    function logCuts() private pure returns(LogCut storage logCut) {
        bytes32 position = LOG_CUT_POSITION;
        assembly{
            logCut.slot := position
        }
    }
    
    function undo() external {
        LibDiamond.enforceIsContractOwner();       
        LibDiamond.diamondCut(logCuts().facetCut[logCuts().logSize-1], address(0),"");
        if (logCuts().logSize >0)
        {
            for (uint i=0;i<=logCuts().facetCut[logCuts().logSize-1].length;i++)
            {
                logCuts().facetCut[logCuts().logSize-1].pop();
            }
            logCuts().logSize--;
        }
    }
}


/*
        //console.log("Length : ",logCuts().facetCut[logCuts().logSize-1].length);
        for (uint i=0;i<logCuts().facetCut[logCuts().logSize-1].length;i++){
            FacetCut memory facetUndo_ = logCuts().facetCut[logCuts().logSize-1][i];
            if (facetUndo_.action == FacetCutAction.Replace) {
                console.log("Replace");
                bytes4[] memory array_ = new bytes4[](1);
                array_[0] = facetUndo_.functionSelectors[0];
                LibDiamond.replaceFunctions(facetUndo_.facetAddress,facetUndo_.functionSelectors);
            }
            if (facetUndo_.action == FacetCutAction.Remove) {
                console.log("Remove");
                LibDiamond.removeFunctions(facetUndo_.facetAddress,facetUndo_.functionSelectors);
            }
            if (facetUndo_.action == FacetCutAction.Add) {
                console.log("Add");
                bytes4[] memory array_ = new bytes4[](1);
                array_[0] = facetUndo_.functionSelectors[0];
                LibDiamond.addFunctions(facetUndo_.facetAddress,array_);
            }
            emit DiamondCut(logCuts().facetCut[logCuts().logSize-1], address(0),"");            
        }
        */