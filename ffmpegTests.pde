void setup(){
  size(1280,720);
  capture = new FfmpegCapture(g,"output.mp4",0,true);
}

boolean running = false;
FfmpegCapture capture;

void draw(){
  background(120);
  fill(0,255,0);
  circle(mouseX,mouseY,100);
  if(running){
    fill(180,255,0);
    rect(0,0,30,30);
    try{
      capture.pushFame();
    }catch(IOException e){
      e.printStackTrace();
    }
  }
}

void mouseClicked(){
  if(running){
    capture.stopRender();
  }else{
    capture.startRender();
  }
  running=!running;
}
