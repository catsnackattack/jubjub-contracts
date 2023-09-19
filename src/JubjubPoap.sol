// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC721} from "solady/tokens/ERC721.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibBitmap} from "solady/utils/LibBitmap.sol";
import {LibString} from "solady/utils/LibString.sol";
import {ISemaphore} from "semaphore/interfaces/ISemaphore.sol";

contract JubjubPoap is ERC721, Ownable {
    using LibBitmap for LibBitmap.Bitmap;
    using LibString for uint256;

    string internal _name;
    string internal _symbol;
    string internal _defaultTokenURI;

    // not needed. handled in semaphore.verifyProof already - https://github.com/semaphore-protocol/semaphore/blob/715b1f8ac56d0c7e33aca96b97cc9c2be5aa47bc/packages/contracts/contracts/Semaphore.sol#L181
    // mapping(bytes32 => bool) public nullifierUsed;
    uint8 currentEdition;
    mapping(uint256 => uint256) public edition; // nft -> signature nonce group
    mapping(uint256 => string) public editionURI; // nonce group -> custom FT

    uint96 public nextTokenId;

    /// @notice the public key of the card managing group
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

    event SignerSet(address signer);

    constructor(IVerifier semaphore_) {
        semaphore = semaphore_;
    }

    function intialize(address owner_, uint256 groupId_, string calldata name_, string calldata symbol_, string calldata tokenURI_, address signer_)
        external
    {
        if (bytes(_name).length == 0) revert AlreadyInitialized();
        if (bytes(name_).length == 0) revert InvalidNameLength();
        _initializeOwner(signer_);
        _name = name_;
        _symbol = symbol_;
        _defaultTokenURI = tokenURI_;
        groupId = groupId_;
        semaphore.createGroup(groupId_, 0 /* TODO: merkleTreeDepth */, signer);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string.concat(_defaultTokenURI, id.toString());
    }

    function setTokenURI(uint256 id, string calldata tokenURI_) onlyOwner() external {
        tokenUriOverrides[id] = tokenURI_;
    }

    function nextEdition(string calldata tokenURI_) onlyOwner() external {
        unchecked {
            ++currentEdition;
        }
        editionURI[currentEdition] = tokenURI_;
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