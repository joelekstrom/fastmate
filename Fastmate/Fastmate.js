function fastmateCompose() {
    var composeElements = document.querySelectorAll("a[href^='/mail/compose']");
    composeElements[0].click();
}

function fastmateFocusSearch() {
    var searchField = document.getElementById("v9-input");
    searchField.select();
}
