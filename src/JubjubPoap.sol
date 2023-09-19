// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC721} from "solady/tokens/ERC721.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibBitmap} from "solady/utils/LibBitmap.sol";
import {LibString} from "solady/utils/LibString.sol";
import {IVerifier} from "./IVerifier.sol";

contract JubjubPoap is ERC721, Ownable {
    using LibBitmap for LibBitmap.Bitmap;
    using LibString for uint256;

    string internal _name;
    string internal _symbol;
    string internal _tokenURI;

    mapping(bytes32 => bool) public nullifierUsed;
    uint96 public nextTokenId;
    address public signer;

    IVerifier public immutable verifier;

    error AlreadyInitialized();
    error InvalidNameLength();
    error NonceReused();
    error NullifierAlreadyUsed();
    error VerificationFailed();

    event SignerSet(address signer);

    constructor(IVerifier verifier_) {
        verifier = verifier_;
    }

    function intialize(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        string calldata tokenURI_,
        address initialSigner
    ) external {
        if (bytes(_name).length == 0) revert AlreadyInitialized();
        if (bytes(name_).length == 0) revert InvalidNameLength();
        _initializeOwner(owner_);
        _name = name_;
        _symbol = symbol_;
        _tokenURI = tokenURI_;
        _setSigner(initialSigner);
    }

    function setSigner(address newSigner) external onlyOwner {
        _setSigner(newSigner);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string.concat(_tokenURI, id.toString());
    }

    function mint(addres to, uint256 nullifierHash, uint256[8] calldata proof) external {
        if (nullifierUsed[nullifier]) revert NullifierAlreadyUsed();
        address signer_ = signer;
        if (!_verify({recipient: to, nullifierHash: nullifierHash, signer_: signer_, proof: proof})) {
            revert VerificationFailed();
        }
    }

    function _setSigner(address newSigner) internal {
        signer = newSigner;
        emit SignerSet(newSigner);
    }

    function _verify(address recipient, uint256 nullifierHash, address signer_, uint256[8] calldata proof)
        internal
        view
        returns (bool)
    {
        try verifier.verifyProof(merkleTreeRoot, nullifierHash, uint160(recipient), externalNullifier, proof, merkleTreeDepth);
    }
}
