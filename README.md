Swift package url: https://github.com/Yummypets/YPImagePicker

```pre
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
```
