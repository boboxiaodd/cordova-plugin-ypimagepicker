var exec = require('cordova/exec');

var PLUGIN_NAME = "CDVYPImagePicker"; // This is just for code completion uses.

var CDVYPImagePicker = function() {}; // This just makes it easier for us to export all of the functions at once.
/*
options:
 type: photo , video , avatar
 size: Integer , max photo width or height
 filter: Bool , enable/disable show filter

return:
  photo / avatar:
    url:   //tmpDirectory file with jpg file type
    width: //photo's width
    height: //photo's height
    size: //file size

  video:
    url: //tmpDirectory file with mp4 file type
    duration: //video duration
    size: //file size
*/
CDVYPImagePicker.open = function(onSuccess, onError , options) {
    exec(onSuccess, onError, PLUGIN_NAME, "open", [options]);
};
CDVYPImagePicker.sheet = function(onSuccess,onError, options, buttons){
    exec(onSuccess,onError,PLUGIN_NAME,"sheet",[options,buttons]);
}
module.exports = CDVYPImagePicker;