// SPDX-License-Identifier: MIT

/*

This contract is part of a system designed to offer a new way to form communities, collaborate on projects, and combine forces to defeat evil. 

*/

pragma solidity ^0.8.0;
import "./talkToken.sol";
import "./talkTag.sol";

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
        uint timeOfPost;
    }

    Post[] public posts;

    talkOnlineToken public talkContract;
    Tag public tagContract;

    event PostCreated(uint indexed postID);
    event PostTagged(uint indexed postId, string indexed tagId, address indexed tagger, string tagName);
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
        emit PostCreated(0);
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
        newPost.timeOfPost = block.timestamp;

        emit PostCreated(postNumber);
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
        emit PostTagged(postId, tagContent, msg.sender, tagContent);
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
    function getPost(uint256 postId) public view returns (address, string memory, uint, uint, uint[] memory, uint, uint) {
        require(postId < posts.length, "Post does not exist");

        Post storage p = posts[postId];
        return (p.author, p.content, p.proScore, p.conScore, p.replies, p.replyingTo, p.timeOfPost);
    }
    /**
    * @dev Structure to hold post details, for batch retrieval.
    */
    struct PostDetails {
        address author;
        string content;
        uint proScore;
        uint conScore;
        uint[] replies;
        uint replyingTo;
        uint timeOfPost;
    }
    /**
    * @dev Fetches details of specific posts by their IDs.
    * @param postIds An array of post IDs to fetch.
    * @return An array of tuples, each containing a post's author, content, pro score, con score, 
    *         replies, the post to which it is replying, and the time of the post.
    */
    function getPosts(uint256[] calldata postIds) public view returns (PostDetails[] memory) {
        PostDetails[] memory postsDetails = new PostDetails[](postIds.length);

        for (uint i = 0; i < postIds.length; i++) {
            require(postIds[i] < posts.length, "Post does not exist");
            Post storage p = posts[postIds[i]];
            postsDetails[i] = PostDetails(p.author, p.content, p.proScore, p.conScore, p.replies, p.replyingTo, p.timeOfPost);
        }

        return postsDetails;
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
    * @param ageThreshold The postID threshold for which replies should be included.
    * @return An array containing the IDs of the replies.
    */
    function getPostReplies(uint256 postId, uint ageThreshold) public view returns (uint[] memory) {
        require(postId < posts.length, "Post does not exist");
        require(ageThreshold < posts.length, "Age threshold too high");

        uint[] memory initReplies = posts[postId].replies;
        if (initReplies.length == 0) {
            return new uint[](0);
        }
        // Check if all replies are newer than the age threshold
        if (initReplies[0] > ageThreshold) {
            return initReplies;
        }

        // Iterates in reverse order, seems like that'll be the efficient way to do it most of the time.
        uint minIndex = initReplies.length - 1;
        while (minIndex > 0 && initReplies[minIndex] > ageThreshold) {
            minIndex--;
        }
    
        uint newLength = initReplies.length - minIndex;
        uint[] memory result = new uint[](newLength);
        for (uint i = 0; i < newLength; i++) {
            result[i] = initReplies[minIndex + i];
        }

        return result;
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
    * @param tags The array of tags to be attached to the post.
    */
    function createPostWithTags(string calldata content, uint replyId, string[] calldata tags) public {
        // Create the post first
        createPost(content, replyId);
        uint256 postId = posts.length - 1;

        // Iterate over each tag and tag the post
        for (uint i = 0; i < tags.length; i++) {
            // Check if the tag exists
            require(tagContract.ownerOf(uint256(keccak256(abi.encodePacked(tags[i])))) != address(0), "Tag does not exist");

            // Tag the post with the current tag
            tagPost(postId, tags[i]);
        }
    }

    /**
     * @dev Returns the IDs of replies to a post, sorted by proScores.
     * @param opId The ID of the original post.
     * @return An array of reply post IDs sorted by their proScores.
     */
    function returnProAlgo(uint opId, uint ageThreshold) public view returns (uint[] memory) {
        uint[] memory replyIds = getPostReplies(opId, ageThreshold);
        uint length = replyIds.length;
        uint[] memory scores = new uint[](length);

        // Populate the scores array
        for (uint i = 0; i < length; i++) {
            scores[i] = posts[replyIds[i]].proScore;
        }

        // Simple Bubble Sort
        for (uint i = 0; i < length; i++) {
            for (uint j = i + 1; j < length; j++) {
                if (scores[j] > scores[i]) {
                    // Swap scores
                    uint tempScore = scores[i];
                    scores[i] = scores[j];
                    scores[j] = tempScore;

                    // Swap corresponding reply IDs
                    uint tempId = replyIds[i];
                    replyIds[i] = replyIds[j];
                    replyIds[j] = tempId;
                }
            }
        }

        return replyIds;
    }
    /**
     * @dev Returns the IDs of replies to a post, sorted by conScores.
     * @param opId The ID of the original post.
     * @return An array of reply post IDs sorted by their conScores.
     */
    function returnConAlgo(uint opId, uint ageThreshold) public view returns (uint[] memory) {
        uint[] memory replyIds = getPostReplies(opId, ageThreshold);
        uint length = replyIds.length;
        uint[] memory scores = new uint[](length);

        // Populate the scores array
        for (uint i = 0; i < length; i++) {
            scores[i] = posts[replyIds[i]].conScore;
        }

        // Simple Bubble Sort
        for (uint i = 0; i < length; i++) {
            for (uint j = i + 1; j < length; j++) {
                if (scores[j] > scores[i]) {
                    // Swap scores
                    uint tempScore = scores[i];
                    scores[i] = scores[j];
                    scores[j] = tempScore;

                    // Swap corresponding reply IDs
                    uint tempId = replyIds[i];
                    replyIds[i] = replyIds[j];
                    replyIds[j] = tempId;
                }
            }
        }
        return replyIds;
    }
}
