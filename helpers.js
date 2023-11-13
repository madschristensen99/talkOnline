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
        
        export async function handleURL(str) {
                var postString = "";
                var fileType = await getFileType(str);
                if (fileType.startsWith('image/')) {
                    // it's an image
                    console.log("image");
                    postString = `<p class = "post-content"><img src="${str}" alt="Post image"/></p>`;
                } else if (fileType.startsWith('video/')) {
                    console.log("video");
                // it's a video
                postString = `<p class = "post-content"><video controls src="${str}">Your browser does not support the video tag.</video></p>`;
                } else if (fileType === 'text/html') {
                    // it's a webpage // TODO: see what actually the link is formatting must be done as https must be used.
                    console.log(`${str}`);
                    var newString = str;
                    newString = newString.replace("https://", "");
                    // TODO: filer format differneces between links sarting with https https, or not. 
                    postString = `<p class = "post-content"><iframe src="https://${newString}" frameborder="0"></iframe></p>`;
                } else {
                    console.log("unknown or other" + str);
                    // unknown or other type TODO: potentially log what the type is so that we can treat other things, but also seems like iframes could cover this field. also, sites like youtube require a specific embed tag in the url for it to work so we can do that here as well. 
                    // IF it ends in .jpg, png, make it an image
                    if (str.endsWith(".gif") || str.endsWith(".png") || str.endsWith(".jpg")){
                        postString = `<p class = "post-content"><img src="${str}" alt="Post image"/></p>`;
                    }
                    // IF it is a youtube link, reformat it to be an embedding
                    else if(str.includes(".be/")){
                        var newString = str;
                        newString = newString.replace(".be/", "be.com/embed/");
                        newString = newString.replace("https://", "");
                        postString = `<p class = "post-content"><iframe src="https://${newString}" frameborder="0"></iframe></p>`;
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
                        postString = `<p class = "post-content"><iframe src="https://${newString}" frameborder="0"></iframe></p>`;
                    }
                    else if(str.includes("live")){
                        var newString = str;
                        newString = newString.replace("live", "embed");
                        newString = newString.replace("https://", "");
                        // https://www.youtube.com/embed/sr56gFUYLg0?si=DuantURvS65ZDjH2 actual
                        // https://www.youtube.com/embed/sr56gFUYLg0?si=2oR4bT7-mZ3RsE42
                        // https://www.youtube.com/embed/sr56gFUYLg0?si=2oR4bT7-mZ3RsE42 desired - that makes no sense 
                        postString = `<p class = "post-content"><iframe src="https://${newString}" frameborder="0"></iframe></p>`;
                    }
                    // else, put it into an iframe
                    else{
                        var newString = str;
                        newString = newString.replace("https://", "");
                        postString = `<p class = "post-content"><iframe src="https://${newString}" frameborder="0"></iframe></p>`;
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
