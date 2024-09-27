# Ffmpeg-for-Processing  
Easy to use solution for making videos from a processing sketch

## Installation
1. Place ffmpeg.pde in your sketch folder
2. \<optionally\> Set ffmpegExe to point at a local ffmpeg installation

## Useage 
create an instacne of FfmpegCapture 
``` processing
FfmpegCapture capture = new FfmpegCapture(g,"output.mp4",0,true);
```
Arguments:  
PGraphics input - what to capture. use `g` to capture the main sketch  
String outputFile - the name of the file to save to  
float fps - the framerate of the output video or 0 for the real time FPS   
boolean printStatusMessages - wther or not to print ffmpeg console output to the console

Note: when called if a valid ffmpeg instalion is not found then the user will be asked if they want to download one

---

Start a render
``` processing
capture.startRender();
```
starts ffmpeg making it ready to be fed frame data

---

Send a frame to ffmpeg
``` processing
capture.pushFame();
```
sends the current frame in the provided PGraphics object to ffmpeg

---

End a render
``` processing
capture.stopRender();
```
stops ffmpeg, saving the finished video file

---
See ffmpegTests.pde for an example
