// SPDX-License-Identifier: MIT

/**

The below three contracts offer a new way to form communities, collaborate on projects, and combine forces to defeat evil. 

talkOnlineToken deploys TALK, an ERC20 token implementing a 24 hr time lock owners can choose to place onto their tokens.

Tag deploys TAG, an ERC721 contract allowing holders of TALK to mint TAG, and allowing TAG owners certain permissions.

Forum instantiates both contracts to initiate a user-controlled forum providing utility for the tokens. 

By aligning incentives, these contracts encourage quality content creation, active voting (curating), and valuable tag creation, which may be beneficial for the growth and vibrancy of the online community.

The contract also enables the monetization of online behavior including credentials. For example, a highly upvoted post can demonstrate expertise in a particular field, which might enhance the author's reputation or job prospects. Creator rewards for quality engagement can be raised through tagging.

*/

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title Talk Online Token
 * @dev This contract deploys the TALK ERC20 token with an added 24hr time lock feature for participants.
 */
contract talkOnlineToken is ERC20 {

    // Mapping of addresses to their last voting timestamps
    mapping(address => uint256) public lastVoteTime;

    /**
     * @dev Constructor that gives the msg.sender all of the initial supply.
     */
    constructor() ERC20("Talk.Online", "TALK") {
        _mint(msg.sender, 100000000 * (10 ** uint256(decimals())));
    }
    /**
     * @dev Locks the token transferability of the caller for 24 hours after participating in a vote.
     */
    function voteLock() public {
        lastVoteTime[tx.origin] = block.timestamp;
    }

    /**
     * @notice Checks whether an address can transfer their tokens based on the voting time lock.
     * @param _from Address to check.
     * @return bool True if the address can transfer, false otherwise.
     */
    function canTransfer(address _from) public view returns (bool) {
        // Check if user has ever voted
        if (lastVoteTime[_from] == 0) {
            return true;
        }
        return (block.timestamp >= lastVoteTime[_from] + 1 days);
    }

    /**
     * @dev Overrides the default transfer function to include a time-lock check.
     * Token locking enables forums built with the token to lock funds, preventing re-use of tokens to vote repeatedly.
     * @param sender Address sending the tokens.
     * @param recipient Address receiving the tokens.
     * @param amount Amount of tokens to transfer.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        require(canTransfer(sender), "Too soon since last participation");
        super._transfer(sender, recipient, amount);
    }

    /**
     * @dev Makes display better
     * @param addy Address being queried
     * @return amount Amount of tokens owner has
     */
    function getLastVoteTime(address addy) public view returns(uint){
        return lastVoteTime[addy];
    }
}
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
        require(talkContract.balanceOf(msg.sender) >  1 ** uint256(talkContract.decimals()), "Must hold at least one TALK token");
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

/**
 * @title Forum
 * @dev Implements a web3 forum on the Ethereum blockchain.
 *
 * The Forum smart contract is an Ethereum-based forum where users can create, edit, upvote, downvote, and tag posts. 
 * It is designed to work in tandem with two other contracts: talkOnlineToken and Tag 
 * which respectively handle token-based operations and the tagging system of the forum. 
 * The forum is aimed at creating a community governed by curation incentives.
*/

contract Forum {

    /**
     * @dev Defines the structure of a forum post.
     */
    struct Post {
        address author;
        string content;
        mapping(address => mapping(uint => bool)) taggedByUser;
        uint [] replies;
        uint replyingTo;
        mapping(address => uint) upvotes;
        mapping(address => uint) downvotes;
        uint proScore;
        uint conScore;
    }

    Post[] public posts;

    talkOnlineToken public talkContract;
    Tag public tagContract;

    event PostCreated(address indexed author, uint postID);
    event PostTagged(uint indexed postId, string indexed tagId, address indexed tagger, string tagName, string modify);
    event PostEdited(uint indexed postId);
    event PostLiked(uint indexed postID, address indexed liker, uint postIDs, address personWhoLiked);
    event PostDisliked(uint indexed postID, address indexed disliker, uint postIDs, address personWhoLiked);

    /**
     * @dev Contract constructor initializes the forum with required contract addresses.
     * @param _talkContract Address of the talkOnlineToken contract.
     * @param _tagContract Address of the Tag contract.
     */

    constructor(address _talkContract, address _tagContract) {
        talkContract = talkOnlineToken(_talkContract);
        tagContract = Tag(_tagContract);
        // Create an initial post
        Post storage newPost = posts.push();
        newPost.author = address(this); // Contract itself is the author of this post
        newPost.content = "Welcome to the Forum! Please follow the guidelines.";
        newPost.proScore = 0;
        newPost.conScore = 0;
        newPost.author = msg.sender;
        emit PostCreated(msg.sender, 0);
    }

    /**
     * @dev Allows a user to create a new post.
     * @param content The content of the post.
     * @param replyId The ID of the post to which this post is a reply.
     * if it's a new thread, the replyId points to post 0
     */
    function createPost(string calldata content, uint replyId) public {
        require(bytes(content).length > 0, "Content field cannot be empty");
        require(replyId < posts.length, "Invalid reply ID");
        Post storage newPost = posts.push();

        newPost.author = msg.sender;
        newPost.content = content;
        uint postNumber = posts.length - 1;
        posts[replyId].replies.push(postNumber);
        newPost.replyingTo = replyId;
        newPost.proScore = 0;
        newPost.conScore = 0;

        emit PostCreated(msg.sender, postNumber);
    }

    /**
     * @dev This function allows a user to tag a post.
     * @param postId The ID of the post to be tagged.
     * @param tagContent The string representation of the tag.
     */
    function tagPost(uint256 postId, string calldata tagContent) public {
        uint id = uint256(keccak256(abi.encodePacked(tagContent)));
        require(tagContract.ownerOf(id) != address(0), "Tag does not exist");
        require(postId < posts.length, "Post does not exist");
        require(talkContract.balanceOf(msg.sender) >= tagContract.getTokenRequirement(tagContent), "Must hold more TALK tokens.");
        require(!posts[postId].taggedByUser[msg.sender][id], "You already tagged this");

        uint256 fee = tagContract.getFee(tagContent);

        if (tagContract.ownerOf(id) != msg.sender && fee > 0 && !tagContract.isExemptFromTagFee(tagContent, msg.sender)) { 
            talkContract.transferFrom(msg.sender, tagContract.ownerOf(id), fee);
        }
        posts[postId].taggedByUser[msg.sender][id] = true;
        // holy moly i gotta admit this is an odd line of code but this is how you fetch a single element from a tuple and return it
        ( , , string memory modifiableField, ) = tagContract.getTagDetails(tagContent);
        emit PostTagged(postId, tagContent, msg.sender, tagContent, modifiableField);
    }

    /**
     * @dev Allows the author to edit their post.
     * @param postId The ID of the post to be edited.
     * @param updatedContent The new content that will replace the old one.
     */
    function editPost(uint256 postId, string calldata updatedContent) public {
        require(postId < posts.length, "Post does not exist");
        require(posts[postId].author == msg.sender, "Only the author can edit the post");
        posts[postId].content = updatedContent;
        emit PostEdited(postId);
    }

    /**
     * @dev Allows a user to upvote a post.
     * @param postId The ID of the post to be upvoted.
     */
    function upvotePost(uint256 postId) public {
        require(talkContract.balanceOf(msg.sender) > 0, "Must hold at least one TALK token to vote");
        require(posts[postId].upvotes[msg.sender] == 0, "Already upvoted");
        require(posts[postId].downvotes[msg.sender] == 0, "Cannot upvote and downvote simultaneously");
        require(posts[postId].author != msg.sender, "Author cannot vote on their own post");

        uint256 amount = talkContract.balanceOf(msg.sender);
        talkContract.voteLock();

        posts[postId].upvotes[msg.sender] = amount;
        posts[postId].proScore += amount;
        emit PostLiked(postId, msg.sender, postId, msg.sender);

    }

    /**
     * @dev Allows a user to downvote a post.
     * @param postId The ID of the post to be downvoted.
     */
    function downvotePost(uint256 postId) public {
        require(talkContract.balanceOf(msg.sender) > 0, "Must hold at least one TALK token to vote");
        require(posts[postId].downvotes[msg.sender] == 0, "Already downvoted");
        require(posts[postId].upvotes[msg.sender] == 0, "Cannot upvote and downvote simultaneously");
        require(posts[postId].author != msg.sender, "Author cannot vote on their own post");

        uint256 amount = talkContract.balanceOf(msg.sender);
        talkContract.voteLock();

        posts[postId].downvotes[msg.sender] = amount;
        posts[postId].conScore += amount;
        emit PostDisliked(postId, msg.sender, postId, msg.sender);
    }
    /**
     * @dev Allows a user to remove an upvote from a post.
     * @param postId The ID of the post from which to remove the upvote.
     */
    function removeUpvote(uint256 postId) public {
        require(posts[postId].upvotes[msg.sender] > 0, "No upvote to remove");
        require(talkContract.balanceOf(msg.sender) >= posts[postId].upvotes[msg.sender], "Must hold at least as many TALK tokens as the upvotes you are removing");
        talkContract.voteLock();
        uint256 amount = posts[postId].upvotes[msg.sender];
        posts[postId].proScore -= amount;
        delete posts[postId].upvotes[msg.sender];
    }

    /**
     * @dev Allows a user to remove a downvote from a post.
     * @param postId The ID of the post from which to remove the downvote.
     */
    function removeDownvote(uint256 postId) public {
        require(posts[postId].downvotes[msg.sender] > 0, "No downvote to remove");
        require(talkContract.balanceOf(msg.sender) >= posts[postId].downvotes[msg.sender], "Must hold at least as many TALK tokens as the downvotes you are removing");
        talkContract.voteLock();
        uint256 amount = posts[postId].downvotes[msg.sender];
        posts[postId].conScore -= amount;
        delete posts[postId].downvotes[msg.sender];
    }

    /**
     * @dev Fetches details of a specific post by its ID.
     * @param postId The ID of the post to fetch.
     * @return A tuple containing the post's author, content, pro score, con score, 
     *         replies, and the post to which it is replying.
     */
    function getPost(uint256 postId) public view returns (address, string memory, uint, uint, uint[] memory, uint) {
        require(postId < posts.length, "Post does not exist");

        Post storage p = posts[postId];
        return (p.author, p.content, p.proScore, p.conScore, p.replies, p.replyingTo);
    }

    /**
     * @dev Fetches the current number of posts in the forum.
     * @return The length of the posts array.
     */
    function getForumLength() public view returns(uint) {
        return posts.length;
    }

    /**
     * @dev Fetches the reply post IDs of a specific post.
     * @param postId The ID of the post for which to fetch replies.
     * @return An array containing the IDs of the replies.
     */
    function getPostReplies(uint256 postId) public view returns (uint[] memory) {
        require(postId < posts.length, "Post does not exist");
        return posts[postId].replies;
    }
    /**
     * @dev Fetches the post ID to which a specific post is replying.
     * @param postId The ID of the post for which to find the replied-to post.
     * @return The ID of the post to which the specific post is replying.
     */
    function getPostReplyingTo(uint256 postId) public view returns (uint) {
        require(postId < posts.length, "Post does not exist");
        return posts[postId].replyingTo;
    }

    /**
     * @dev Fetches the upvotes of a specific post for a specific user.
     * @param postId The ID of the post.
     * @param user The address of the user.
     * @return The number of upvotes by the user on the post.
     */
    function getPostUpvotes(uint256 postId, address user) public view returns (uint) {
        require(postId < posts.length, "Post does not exist");
        return posts[postId].upvotes[user];
    }

    /**
     * @dev Fetches the downvotes of a specific post for a specific user.
     * @param postId The ID of the post.
     * @param user The address of the user.
     * @return The number of downvotes by the user on the post.
     */
    function getPostDownvotes(uint256 postId, address user) public view returns (uint) {
        require(postId < posts.length, "Post does not exist");
        return posts[postId].downvotes[user];
    }
    /**
     * @dev Fetches the con score of a specific post.
     * @param postId The ID of the post.
     * @return The con score of the post.
     */
    function getConScore(uint256 postId) public view returns (uint) {
        require(postId < posts.length, "Post does not exist");
        return posts[postId].conScore;
    }
    /**
     * @dev Fetches the pro score of a specific post.
     * @param postId The ID of the post.
     * @return The pro score of the post.
     */
    function getProScore(uint256 postId) public view returns (uint) {
        require(postId < posts.length, "Post does not exist");
        return posts[postId].proScore;
    }
    /**
     * @dev Allows a user to create a new post and tag it simultaneously.
     * @param content The content of the post.
     * @param replyId The ID of the post to which this post will reply.
     * @param tag The tag to be attached to the post.
     */
    function createPostWithTag(string calldata content, uint replyId, string calldata tag) public {
        require(tagContract.ownerOf(uint256(keccak256(abi.encodePacked(tag)))) != address(0), "Tag does not exist");
        createPost(content, replyId);
        tagPost(posts.length - 1, tag); 
    }

}
