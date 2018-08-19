function fastmateCompose() {
    var composeElements = document.querySelectorAll("a[href^='/mail/compose']");
    composeElements[0].click();
}

function fastmateFocusSearch() {
    var searchField = document.getElementById("v9-input");
    searchField.select();
}

function fastmateGetToolbarColor() {
    var toolbar = document.getElementsByClassName("app-toolbar")[0];
    var style = window.getComputedStyle(toolbar);
    var color = style.getPropertyValue('background-color');
    return color;
}
