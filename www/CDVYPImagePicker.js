var exec = require('cordova/exec');

var PLUGIN_NAME = "CDVYPImagePicker"; // This is just for code completion uses.

var CDVYPImagePicker = function() {}; // This just makes it easier for us to export all of the functions at once.
// All of your plugin functions go below this.
// Note: We are not passing any options in the [] block for this, so make sure you include the empty [] block.
CDVYPImagePicker.open = function(onSuccess, onError , type) {
    exec(onSuccess, onError, PLUGIN_NAME, "open", [type]);
};
module.exports = CDVYPImagePicker;