// SPDX-License-Identifier: MIT

/*

This contract is part of a system designed to offer a new way to form communities, collaborate on projects, and combine forces to defeat evil. 

Tag deploys TAG, an ERC721 contract allowing holders of TALK to mint TAG, and allowing TAG owners certain permissions.

*/

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./talkToken.sol";

/**
 * @title Tag Contract
 * @dev This contract is an ERC721 Enumerable that allows users to create and manage tags. Qualitative curation framework. 
 */
contract Tag is ERC721Enumerable {

    talkOnlineToken public talkContract;
    /**
     * @dev Represents the details of a tag.
     */
    struct TagDetails {
        uint256 ethFee;              // Fee in ETH to use this tag
        uint256 tokenRequirement;   // Amount of talkContract required to hold for using this tag
        string modifiableField;
        uint lastModify;
        mapping(address => bool) exemptedAccounts;
    }
    mapping(uint256 => TagDetails) public tags;
    mapping(address => uint256) public lastTagCreationTime;

    event TagCreated(string tag, address indexed owner);
    event TagModified(string indexed tag, address indexed owner, string modification);
    event TagFeeUpdated(string indexed tag, uint256 newEthFee);
    event TokenRequirementUpdated(string indexed tag, uint256 newTokenRequirement);
    event ExemptionStatusUpdated(string indexed tag, address indexed account, bool isExempted);

    /**
     * @dev Initializes the Tag contract with a TALK token contract address.
     * @param _talkContract The address of the TALK token contract.
     */
    constructor(address _talkContract) ERC721("TagToken", "TAG") {
        talkContract = talkOnlineToken(_talkContract);
    }

    uint256 public constant TAG_CREATION_INTERVAL = 1 hours;

    /**
     * @dev Creates a new tag. Fundaraisers, creator and curator rewards
     * @param tagContent The content of the tag.
     */

    function createTag(string memory tagContent) public {
        require(talkContract.balanceOf(msg.sender) >  10 ** uint256(talkContract.decimals()), "Must hold at least one TALK token");
        require(block.timestamp >= lastTagCreationTime[msg.sender] + TAG_CREATION_INTERVAL, "You must wait for 1 hour between crafting tags");
        talkContract.voteLock();
        _mint(msg.sender, uint256(keccak256(bytes(tagContent))));
        lastTagCreationTime[msg.sender] = block.timestamp;
        emit TagCreated(tagContent, msg.sender);
    }

    /**
     * @dev Updates the ETH fee for using a tag. Paid messaging, spam disincentive. 
     * @param tagContent The content of the tag.
     * @param newEthFee The new ETH fee.
     */
    function updateTagFee(string memory tagContent, uint256 newEthFee) public {
        require(talkContract.balanceOf(msg.sender) > 0, "Must hold at least one TALK token");
        uint256 tokenId = uint256(keccak256(bytes(tagContent)));
        require(ownerOf(tokenId) != address(0), "Tag does not exist");
        require(ownerOf(tokenId) == msg.sender, "You are not the owner");
        
        tags[tokenId].ethFee = newEthFee;
        emit TagFeeUpdated(tagContent, newEthFee);
    }

    /**
     * @dev Updates the TALK token requirement for using a tag.
     * @param tagContent The content of the tag.
     * @param newTokenRequirement The new TALK token requirement.
     */
     
    function updateTokenRequirement(string memory tagContent, uint256 newTokenRequirement) public {
        uint256 tokenId = uint256(keccak256(bytes(tagContent)));
        require(ownerOf(tokenId) != address(0), "Tag does not exist");
        require(ownerOf(tokenId) == msg.sender, "You are not the owner");
        require(talkContract.balanceOf(tx.origin) >= newTokenRequirement, "You cannot set a token requirement higher than your currrent balance.");

        
        tags[tokenId].tokenRequirement = newTokenRequirement;
        emit TokenRequirementUpdated(tagContent, newTokenRequirement);
    }
    /**
     * @dev Allows the tag owner to exempt an address from the ETH fee for using the tag
     * Useful for trusted community members or moderators. Enables permissioned system within permissionless forum.
     * @param tagContent The content of the tag to update
     * @param account The address to exempt
     */
    function exemptFromTagFee(string memory tagContent, address account) public {
        uint256 tokenId = uint256(keccak256(bytes(tagContent)));
        require(ownerOf(tokenId) != address(0), "Tag does not exist");
        require(ownerOf(tokenId) == msg.sender, "You are not the owner");
        require(!tags[tokenId].exemptedAccounts[account], "Account is already exempted");
        tags[tokenId].exemptedAccounts[account] = true;
        emit ExemptionStatusUpdated(tagContent, account, true);
    }

    /**
     * @dev Allows the tag owner to remove the exemption status of an address
     * This can be useful in case the trust level changes or if the exemption is no longer required.
     * @param tagContent The content of the tag to update
     * @param account The address to remove the exemption from
     */
    function removeExemptionFromTagFee(string memory tagContent, address account) public {
        uint256 tokenId = uint256(keccak256(bytes(tagContent)));
        require(ownerOf(tokenId) != address(0), "Tag does not exist");
        require(ownerOf(tokenId) == msg.sender, "You are not the owner");
        require(tags[tokenId].exemptedAccounts[account], "Account is not exempted");
        tags[tokenId].exemptedAccounts[account] = false;
        emit ExemptionStatusUpdated(tagContent, account, false);
    }

    function getFee(string memory tagContent) public view returns(uint256) {
        uint256 tokenId = uint256(keccak256(bytes(tagContent)));
        return tags[tokenId].ethFee;
    }
    /**
     * @dev Owner modifies field
     * @param tagContent The content of the tag to be updated
     * @param input The info owner can change about the tag can only change once every 24 hrs
     */
    function modifyField (string memory tagContent, string calldata input) public{
        uint256 tokenId = uint256(keccak256(bytes(tagContent)));
        require(ownerOf(tokenId) != address(0), "Tag does not exist");
        require(ownerOf(tokenId) == msg.sender, "You are not the owner");
        require(tags[tokenId].lastModify < block.timestamp + 1 days, "Too soon since last modification");
        tags[tokenId].modifiableField = input;
        tags[tokenId].lastModify = block.timestamp;
        emit TagModified(tagContent, msg.sender, input);
    }
    /**
     * @dev View function to get the ETH fee for a specific tag
     * @param tagContent The content of the tag
     * @return The ETH fee for the tag
     */
    function getTokenRequirement(string memory tagContent) public view returns(uint256) {
        uint256 tokenId = uint256(keccak256(bytes(tagContent)));
        return tags[tokenId].tokenRequirement;
    }

    /**
     * @dev View function to check if an address is exempted from the ETH fee for a specific tag
     * @param tagContent The content of the tag
     * @param account The address to check
     * @return True if the address is exempted, false otherwise
     */
    function isExemptFromTagFee(string memory tagContent, address account) public view returns(bool) {
        uint256 tokenId = uint256(keccak256(bytes(tagContent)));
        return tags[tokenId].exemptedAccounts[account];
    }

    /**
     * @dev View function to get the detailed information of a specific tag
     * @param tagContent The content of the tag
     * @return The ETH fee and TALK token holding requirement for the tag, and the modifiable field and the tagID
     */
    function getTagDetails(string memory tagContent) public view returns (uint256, uint256, string memory, uint256) {
        uint256 tokenId = uint256(keccak256(bytes(tagContent)));
        return (
            tags[tokenId].ethFee,
            tags[tokenId].tokenRequirement,
            tags[tokenId].modifiableField,
            uint256(keccak256(bytes(tagContent)))
        );
    }

}
