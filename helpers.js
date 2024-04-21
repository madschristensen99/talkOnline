        // FILE: Helpers
        export async function getFileType(url) {
            try {
                let response = await fetch(url, { method: 'HEAD' });
                let contentType = response.headers.get('Content-Type');
                if (!contentType) {
                    return 'unknown';
                }
                return contentType;
            } catch (error) {
                console.error('Could not determine file type:', error);
                return 'unknown';
            }
        }
        export async function getENSName(address, provider) {
            try {
                // TODO: create link to address page
                const ensName = await provider.lookupAddress(address);
                if (ensName) {
                    return `<a href = "${address}" class="ens-link">${ensName}</a>`;
                } else {
                    return `<a href = "${address}" class="address-link">${address}</a>`;
                }
            } catch (error) {
                console.error(`Error occurred: ${error}`);
                return `<a href = "${address}" class="address-link">${address}</a>`;
            }
        }

        export function isURL(str) {
            var pattern = new RegExp('^(https?:\\/\\/)?'+ // protocol
            '((([a-z\\d]([a-z\\d-]*[a-z\\d])*)\\.)+[a-z]{2,}|'+ // domain name and extension
            '((\\d{1,3}\\.){3}\\d{1,3}))'+ // OR ip (v4) address
            '(\\:\\d+)?'+ // port
            '(\\/[-a-z\\d%_.~+]*)*'+ // path
            '(\\?[;&a-z\\d%_.~+=-]*)?'+ // query string
            '(\\#[-a-z\\d_]*)?$','i'); // fragment locator
            return !!pattern.test(str);
        }
        
        export async function handleURL(str, contentClass) {
                var postString = "";
                var fileType = await getFileType(str);
                if (fileType.startsWith('image/')) {
                    // it's an image
                    console.log("image");
                    postString = `<div class = "${contentClass}"><img src="${str}" alt="Post image"/></div>`;
                } else if (fileType.startsWith('video/')) {
                    console.log("video");
                // it's a video
                postString = `<div class = "${contentClass}"><video controls src="${str}">Your browser does not support the video tag.</video></div>`;
                } else if (fileType === 'text/html') {
                    // it's a webpage // TODO: see what actually the link is formatting must be done as https must be used.
                    console.log(`${str}`);
                    var newString = str;
                    newString = newString.replace("https://", "");
                    // TODO: filer format differneces between links sarting with https https, or not. 
                    postString = `<div class = "${contentClass}"><iframe src="https://${newString}" frameborder="0"></iframe></div>`;
                } else {
                    console.log("unknown or other" + str);
                    // unknown or other type TODO: potentially log what the type is so that we can treat other things, but also seems like iframes could cover this field. also, sites like youtube require a specific embed tag in the url for it to work so we can do that here as well. 
                    // IF it ends in .jpg, png, make it an image
                    if (str.endsWith(".gif") || str.endsWith(".png") || str.endsWith(".jpg") || str.endsWith(".jpeg")){
                        postString = `<div class = "${contentClass}"><img src="${str}" alt="Post image"/></div>`;
                    }
                    // IF it is a youtube link, reformat it to be an embedding
                    else if(str.includes(".be/")){
                        var newString = str;
                        newString = newString.replace(".be/", "be.com/embed/");
                        newString = newString.replace("https://", "");
                        postString = `<div class = "${contentClass}"><iframe src="https://${newString}" frameborder="0"></iframe></div>`;
                    }
                    else if(str.includes("watch?v=")){
                        var newString = str;
                        newString = newString.replace("watch?v=", "embed/");
                        newString = newString.replace("https://", "");
                        console.log(newString);
                        newString = newString.replace("&start_radio=1", "");
                        newString = newString.replace("&list=RDMME8LIxsJLkbc", "");
                        newString = newString.replace("?si=tKTSlEDYEMHlbhLc", "");
                        console.log(newString);
                        postString = `<div class = "${contentClass}"><iframe src="https://${newString}" frameborder="0"></iframe></div>`;
                    }
                    else if(str.includes("live")){
                        var newString = str;
                        newString = newString.replace("live", "embed");
                        newString = newString.replace("https://", "");
                        // https://www.youtube.com/embed/sr56gFUYLg0?si=DuantURvS65ZDjH2 actual
                        // https://www.youtube.com/embed/sr56gFUYLg0?si=2oR4bT7-mZ3RsE42
                        // https://www.youtube.com/embed/sr56gFUYLg0?si=2oR4bT7-mZ3RsE42 desired - that makes no sense 
                        postString = `<div class = "${contentClass}"><iframe src="https://${newString}" frameborder="0"></iframe></div>`;
                    }
                    // else, put it into an iframe
                    else{
                        var newString = str;
                        newString = newString.replace("https://", "");
                        postString = `<div class = "${contentClass}"><iframe src="https://${newString}" frameborder="0"></iframe></div>`;
                    }
                }
            return postString;
        }
        
export async function formatDateForDisplay(date) {
    const monthNames = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];

    const daySuffix = n => {
        if (n >= 11 && n <= 13) return 'th';
        switch (n % 10) {
            case 1: return 'st';
            case 2: return 'nd';
            case 3: return 'rd';
            default: return 'th';
        }
    };

    const month = monthNames[date.getMonth()];
    const day = date.getDate();
    const year = date.getFullYear();
    const hours = date.getHours();
    const minutes = date.getMinutes();
    const ampm = hours >= 12 ? 'pm' : 'am';
    
    const formattedHours = hours % 12 || 12; // Convert to 12 hour format
    const formattedMinutes = minutes.toString().padStart(2, '0'); // Pad with leading 0 if necessary

    return `${month} ${day}${daySuffix(day)} ${year} ${formattedHours}:${formattedMinutes} ${ampm}`;
}

export async function buttonMaker(){
                    let output = `<footer id = \"givenPostsFooter\"><button class=\"upvote-button\">^</button><button class=\"downvote-button\">v</button><button class=\"tag-button\">Tag</button><button class=\"reply-button\">Reply</button>` +
                        `<div class="input-tag" hidden><input type="text" class="input-field-tag" placeholder="Enter Tag name"><button class="submit-tag">Add Tag</button></div></footer>`+
                        `<div class="input-reply" hidden><input type="text" class="input-field-reply" placeholder="Please be nice..."><button class="submit-reply">Reply</button></div></footer>`;
                    return output;
                }
                
                export async function fetchReplies(postID, contractObject){

                    let newz = await contractObject.getPost(postID);
                    let replyArr = [];

                    for (const element of newz[4]) {
                        console.log(parseInt(element._hex, 16)); // Log the parsed element

                        let fullReplyInformation = await contractObject.getPost(parseInt(element._hex, 16)); // Await the asynchronous call
                        if (isURL(fullReplyInformation[1])){
                            
                        }
                        replyArr.push(`>` + fullReplyInformation[1] + `<br>`);
                        // TODO: fetch information about sub-replies
                    }
                    // TODO: HERE: replyArr formatting
                    return replyArr;
                }

                export async function fetchTags(postID, contractObject) {

                    // Create a filter for the 'PostTagged' event where the first argument (postId) matches the given postID
                    const filter = contractObject.filters.PostTagged(postID, null, null);

                    // Query the event logs with the filter
                    const logs = await contractObject.queryFilter(filter);
                    let tags = `<div class="tag-container">`;
                    for(var i = 0; i < logs.length; i ++){
                        let newCo = logs[i].args[3];
                        // modifier
                        if(isURL(logs[i].args[4])){
                            newCo = `<a href="https://talk.online/${newCo}">` + await handleURL(logs[i].args[4], "tag-content") + `</a>`;
                        }
                        else{
                            newCo = `<a href="https://talk.online/${newCo}">` + newCo.slice(0, 12) + `</a>`;
                        }
                        tags += newCo;
                    }
                    tags += `</div>`;
                    if(logs.length == 0){
                        tags = `<div id = "noTagMessage"></div>`;
                    }
                    return tags;
                }
                // TODO: getPosts as id field should actually be ids that we want to load
                export async function loadContent(id, contract, provider){
                    let content = await contract.getPost(id);
                    let ensName = await getENSName(content[0], provider);
                    
                    // TODO: turn date getter into its own function
                    const events = await contract.queryFilter(contract.filters.PostCreated(id));
                    let dateField = "Day One";
                    
                    try{
                        const blockNumber = events[0].blockNumber;
                        const block = await provider.getBlock(blockNumber);
                        const timestamp = block.timestamp;
                        const dateObject = new Date(timestamp * 1000);
                        const humanReadableDate = await formatDateForDisplay(dateObject);
                        dateField = humanReadableDate;
                    }
                    catch(error){
                        console.log("post Event not found could be because its the 0th post");
                    }
                    
                    // TODO: turn setup header into its own function
                    let postHTML = "<h1>";
                    postHTML += `<div style="display: flex; justify-content: space-between;">`;
                    postHTML += dateField;
                    postHTML += `<a href="https://talk.online/${id.toString()}" text-align: right;>${id.toString()}</a></div>`
                    // TODO: make this work even if network does not support ens
                    postHTML +=  ensName;
                    postHTML += "</h1>";
                    
                    if(isURL(content[1])){
                        postHTML += await handleURL(content[1], "post-content");
                    } else {
                        // not a url, just use it as text
                        console.log("text");
                        postHTML += `<p class = "post-content">${content[1]}</p>`;
                    }
                    
                    var footer = await buttonMaker();
                    postHTML += footer;
                    // TODO: add id to this so that way nearest score can be updated in interface
                    postHTML += `<table class = "postInfo"><tr> <td class ="one-sixth" id = "netScore">` + ((content[2] - content[3]) / (10 ** 18)).toString();
                    let tagAwait = await fetchTags(id, contract);
                    postHTML += `</td> <td class="two-thirds">` + tagAwait + `</td>`;
                    postHTML += `<td class="one-sixth" id = "clickableReplies">Replies: ` + content[4].length.toString() + `</td> </tr> </table>`;
                    return postHTML;
                }
                
                export async function activateContent(signerObject){
                    document.getElementById('createPost').addEventListener('submit', async (e) => {
                        // Prevent the default form submission
                        e.preventDefault();

                        // Get the post content from the textarea
                        const postContent = document.getElementById('post-content').value;

                        if (!postContent.trim()) {
                            alert("Post content is empty. Please write something.");
                            return;
                        }

                        // Create a new post by calling the `createPost` function on the contract

                        try {
                            // Send the transaction and wait for it to be mined
                            let tx = await signerObject.createPost(postContent, 0);
                            let receipt = await tx.wait();
                            console.log('Transaction has been mined: ', receipt.transactionHash);
                            // Clear the textarea after successful post creation
                            document.getElementById('post-content').value = '';
                        } catch (error) {
                            // Handle any errors
                            console.error('An error occurred:', error);
                        }
                    });

                    document.addEventListener('click', async (e) => {
                        const postElement = e.target.closest('article');  // Find the parent article
                        if (!postElement) return;  // If clicked outside a post, exit
                        // Fetch the post ID from the link in the post header
                        const postIDLink = postElement.querySelector('h1 a');
                        if (!postIDLink) return;  // If the link isn't found, exit
                        const postID = postIDLink.textContent;
                        // Check if the 'Tag' or 'Reply' buttons were clicked
                        let action;
                        if (e.target.classList.contains('tag-button')) {
                            const inputWrapper = postElement.querySelector('.input-tag');
                            const inputField = postElement.querySelector('.input-field');
                            inputWrapper.toggleAttribute('hidden'); // Toggle visibility
                            inputField.focus(); // Focus on the field for immediate typing
                            action = "tag";
                        }
                        else if (e.target.classList.contains('reply-button')){
                            const inputWrapper = postElement.querySelector('.input-reply');
                            const inputField = postElement.querySelector('.input-field');
                            inputWrapper.toggleAttribute('hidden'); // Toggle visibility
                            inputField.focus(); // Focus on the field for immediate typing
                            action = "reply";
                        }
                        else if (e.target.classList.contains('upvote-button')){
                            try{
                                // TODO: update score on interface 
                                // .closest('#givenPostsFooter');
                                // document.getElementById("netScore").innerHTML
                                await signerObject.upvotePost(postID);
                            }
                            catch (error){
                                let errorElement = e.target.closest('#givenPostsFooter');
                                let analysis = error.message;//TODO: already voted on post, cant vote on your own post
                                console.log(analysis);
                                if (analysis.includes("Already")){
                                    errorElement.innerHTML += `You've already voted on this post. `;
                                }
                                else if (analysis.includes("Author")){
                                    errorElement.innerHTML += `You are the post owner. `;
                                }
                                else{
                                    errorElement.innerHTML += `You don't hold <a href="./token.html">TALK tokens</a> `;
                                }
                            }
                        }
                        else if (e.target.classList.contains('downvote-button')){
                            try{
                                // TODO: update score on interface
                                await signerObject.downvotePost(postID);
                            }
                            catch (error){
                                let errorElement = e.target.closest('#givenPostsFooter');
                                let analysis = error.message;//TODO: already voted on post, cant vote on your own post
                                if (analysis.includes("Already")){
                                    errorElement.innerHTML += `You've already voted on this post. `;
                                }
                                else if (analysis.includes("Author")){
                                    errorElement.innerHTML += `You are the post owner. `;
                                }
                                else{
                                    errorElement.innerHTML += `You don't hold <a href="./token.html">TALK tokens</a> `;
                                }
                            }
                        }

                        else if (e.target.classList.contains('submit-tag')) {
                            console.log("tagg");
                            
                            const inputField = postElement.querySelector('.input-field-tag');
                            const inputValue = inputField.value.trim();
                            console.log(inputValue);
                            try {
                                await signerObject.tagPost(postID, inputValue);
                            }
                            catch (error){
                                let errorElement = e.target.closest('#givenPostsFooter');
                                errorElement.innerHTML += `That's an invalid <a href="./tags.html">tag.</a> `;
                            }
                        }
                        else if (e.target.classList.contains('submit-reply')) {
                            const inputField = postElement.querySelector('.input-field-reply');
                            const inputValue = inputField.value.trim();
                            signerObject.createPost(inputValue, postID);
                        }
                    });
                }
                
