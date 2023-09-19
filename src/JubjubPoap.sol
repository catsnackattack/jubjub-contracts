// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC721} from "solady/tokens/ERC721.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibBitmap} from "solady/utils/LibBitmap.sol";
import {LibString} from "solady/utils/LibString.sol";
import {ISemaphore} from "semaphore/interfaces/ISemaphore.sol";

contract JubjubPoap is ERC721 {
    using LibBitmap for LibBitmap.Bitmap;
    using LibString for uint256;

    string internal _name;
    string internal _symbol;
    string internal _defaultTokenURI;

    // not needed. handled in semaphore.verifyProof already - https://github.com/semaphore-protocol/semaphore/blob/715b1f8ac56d0c7e33aca96b97cc9c2be5aa47bc/packages/contracts/contracts/Semaphore.sol#L181
    // mapping(bytes32 => bool) public nullifierUsed;
    mapping(uint256 => uint256) public nonces; // nft -> signature nonce #
    mapping(uint256 => uint8) public editions; // nft -> signature nonce group
    mapping(uint8 => string) public editionURIs; // edition -> custom NFT art
    
    /// @notice nonce group that all NFTs currently minted should be added to
    uint8 public currentEdition;
    uint96 public nextTokenId;

    /// @notice 
    address public signer;
    /// @notice semaphore group id this contract is managing
    address public groupId;
    /// @notice Sempahore singleton group manager contract to control access to this group
    ISemaphore public immutable semaphore;

    error AlreadyInitialized();
    error InvalidNameLength();
    error NonceReused();
    error NullifierAlreadyUsed();
    error VerificationFailed();
    error NotAdmin();
    error AddMemberFailed();

    constructor(ISemaphore semaphore_) {
        semaphore = semaphore_;
    }

    /**
     @notice -
     @param signer_ - the public key of the card managing this group
     @param groupID_ - semaphore group id for ACL and nullifiers
     @param name_ - NFT token name
     @param symbol_ - NFT token symbol
     @param tokenURI_ - default NFT art to display
    */
    function intialize(address signer_, uint256 groupId_, string calldata name_, string calldata symbol_, string calldata tokenURI_)
        external
    {
        if (bytes(_name).length == 0) revert AlreadyInitialized();
        if (bytes(name_).length == 0) revert InvalidNameLength();
        _name = name_;
        _symbol = symbol_;
        _defaultTokenURI = tokenURI_;

        signer = signer_;
        groupId = groupId_;
        semaphore.createGroup(groupId_, 0 /* TODO: merkleTreeDepth */, signer_);
    }

    modifier onlyOwner() {
        if (!msg.sender == signer) revert NotAdmin();
        _;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        string memory targetURI = editionURIs[editions[id]];
        if(bytes(targetURI).length == 0) {
            return string.concat(_defaultTokenURI, id.toString());
        } else {
            return targetURI;
        }
    }

    function nextEdition(string calldata tokenURI_) onlyOwner() external {
        unchecked {
            ++currentEdition;
        }
        editionURIs[currentEdition] = tokenURI_;
    }

    function mint(bytes32 nullifierHash, address recipient, uint266 idCommitment, bytes memory signature, uint256[8] calldata proof) external {
        // address signer_ = signer;
        // if (!semaphore.verify(signer_, nullifierHash, proof)) revert VerificationFailed();

        if (!semaphore.verifyProof(
            groupId,
            0, /* merkel tree root */
            uint256(recipient), /* signal aka recipient address */
            nullifierHash,
            groupId, /* external nullifier */
            proof
        )) revert VerificationFailed();


        try(semaphore.addMember(groupId_, idCommitment)) {
            _mint(recipient, nextTokenId);
            edition[nextTokenId] = currentEdition;
            // TODO get signature nonce from proof
            // nonce[nextTokenId] = signatureNonce;

            unchecked {
                ++nextTokenId;
            }
        } catch(bytes memory) {
            revert AddMemberFailed();
        }
    }

    /**
     * functions to delegate more functionality to Semaphore instead of contract specific ACL
    */
    // function updateAdmin(address newAdmin) internal onlyOwner() {
    //     semaphore.updateGroupAdmin(groupId, newAdmin);
    // }
    
    /// @notice override default check to look at semaphore group admin instead of local contract data
    // function _checkOwner() internal view override virtual returns(bool) {
    //     return semaphore.groups(groupId).admin == msg.sender;
    // }


}