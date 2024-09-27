import java.nio.ByteBuffer;
import java.nio.channels.WritableByteChannel;
import java.nio.channels.Channels;
import java.io.ByteArrayOutputStream;
import java.io.ByteArrayInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URL;
import java.net.URLConnection;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import javax.swing.JOptionPane;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
//ffmped commandline
//ffmpeg.exe -y -f rawvideo -pix_fmt argb -s WIDTHxHEIGHT -r 60 -i - -an -c:v libx264 -b:v 20971520 -pix_fmt yuv420p "output.mp4"
String ffmpegExe = "";//make sure to set this in your sketch to be the right path or don't set it and allow the user to download it 
class FfmpegCapture {
  int exportBitrate = 20971520;

  ByteBuffer rawFrameBuffer;
  Process ffmpeg;
  OutputStream ffmpegSTDin;
  WritableByteChannel ffmpegSTDinChannel;
  
  private PGraphics captureSource;
  private String outputFile;
  private float frameRate;
  private boolean printDebugMessage;
  private boolean rendering = false;
  
  /**create an ffmpeg capture
  @param input the pgraphics object to capture from
  @param outputFile the name/path of the output video file
  @param fps the frame rate of the video or 00 for what every the real time capture fps is
  */
  public FfmpegCapture(PGraphics input,String outputFile,float fps,boolean printStatusMessages){
   this.captureSource = input;
   if(!new File(outputFile).isAbsolute()){
     outputFile=sketchPath()+"/"+outputFile;
   }
   this.outputFile=outputFile;
   frameRate=fps;
   printDebugMessage=printStatusMessages;
   //check to see if ffmpeg exsists at the pointed to location
   if(!checkFfmpegExsists()){
     //if it does not exsist then ask the user if they want to download it
     int choice  = JOptionPane.showConfirmDialog(null,"FFmpeg not found,\ndo you want to download it now?","Install FFMpeg",JOptionPane.YES_NO_OPTION);
     if(choice == 0){
     //if yes then download, if no then error
       //pop up download winodw
       JFrame frame;
       JPanel panel;
       frame= new JFrame();
       frame.setSize(600, 400);
    
       panel= new JPanel();
       frame.add(panel);
       frame.setVisible(true);
       //frame.addWindowListener(this);
       panel.setLayout(null);
       frame.setTitle("Downloading FFMpeg"); 
       JLabel wtext = new JLabel("Dowloading FFMpeg, please wait");
       wtext.setBounds(10, 20, 300, 200);
       panel.add(wtext);
       panel.repaint();
       
       try{//do the download
         downloadFFMpeg(new long[]{0,0});
       }catch(IOException e){
         //show an error messages
         wtext.setText("An error occored: "+e.getMessage());
         throw new RuntimeException("FFMpeg download failed",e);
       }
       //close dowloading winodw
       frame.dispose();
     }else{
       throw new RuntimeException("FFMpeg not found!");
     }
   }
  }
  
  /**start/initilize ffmpeg 
  */
  public void startRender() {
    if(!rendering){
      captureSource.loadPixels();
      //create the buffer to store the byte verison of the frame in
      rawFrameBuffer = ByteBuffer.allocate(captureSource.pixels.length*4);
      //start ffmpeg
      if(frameRate>0){
      ffmpeg = exec(ffmpegExe, "-y", "-f", "rawvideo", "-pix_fmt", "argb",
        "-s", captureSource.width+"x"+captureSource.height, "-r",frameRate+"",
        "-i", "-", "-an", "-c:v", "libx264",
        "-b:v", exportBitrate+"",
        "-pix_fmt", "yuv420p", outputFile);
      }else{
        ffmpeg = exec(ffmpegExe, "-y", "-f", "rawvideo", "-pix_fmt", "argb",
        "-s", captureSource.width+"x"+captureSource.height,
        "-i", "-", "-an", "-c:v", "libx264",
        "-b:v", exportBitrate+"",
        "-pix_fmt", "yuv420p", outputFile);
      }
      ffmpegSTDin = ffmpeg.getOutputStream();
      ffmpegSTDinChannel = Channels.newChannel(ffmpegSTDin);
      new LineThread2(ffmpeg.getInputStream(), false, printDebugMessage).stopGivingMeAWarningProcessing();
      new LineThread2(ffmpeg.getErrorStream(), true, printDebugMessage).stopGivingMeAWarningProcessing();
      rendering=true;
    }else{
      System.err.println("Warning: attempted to call FfmpegCapture.startRender() while a render was in progress.");
    }
  }

  /**save the current frame of the pgraphics object to ffmpeg
  */
  public void pushFame() throws IOException {
    if(rendering){
      captureSource.loadPixels();
      rawFrameBuffer.clear();
      for (int i : captureSource.pixels) {
        rawFrameBuffer.putInt(i);
      }
      rawFrameBuffer.rewind();
  
      ffmpegSTDinChannel.write(rawFrameBuffer);
    }else{
      System.err.println("Warning: attempted to call FfmpegCapture.pushFame() without starting a render first");
    }
  }

  /**end the current render and save the final video file
  */
  public void stopRender() {
    //close stdin for ffmpeg
    if(rendering){
      try {
        ffmpegSTDin.close();
      }
      catch( Exception e) {
      }
      int start = millis();
  
      while (millis()<start+30000) {
        try {
          //try to read the exit value from ffmpeg
          ffmpeg.exitValue();
          break;
          //if we cant then wait 100ms and try again for at most 30s
        }
        catch(IllegalThreadStateException e) {
          try {
            Thread.sleep(100);
          }
          catch(InterruptedException iiii) {
          };
        }
      }
      //destory the process
      ffmpeg.destroy();
      rendering = false;
    }else{
      System.err.println("Warning: attempted to call FfmpegCapture.stopRender() without starting a render first");
    }
  }

  /**copy of an internal processing class for handling the output streams of a program
  */
  class LineThread2 extends Thread {
    InputStream input;
    boolean error;
    boolean print;

    /**
    @param inpput thestream to pull from
    @param error wther this is an error stream
    @param printLogs wether to print the output to the console
    */
    LineThread2(InputStream input, boolean error, boolean printLogs) {
      this.input = input;
      this.error=error;
      this.print=printLogs;
      start();
    }

    @Override
      public void run() {
      // It's not sufficient to use BufferedReader, because if the app being
      // called fills up stdout or stderr to quickly, the app will hang.
      // Instead, write to a byte[] array and then parse it once finished.
      try {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        saveStream(baos, input);
        BufferedReader reader =
          createReader(new ByteArrayInputStream(baos.toByteArray()));
        String line;
        while ((line = reader.readLine()) != null) {
          if(print){
          if (error) {
            System.err.println(line);
          } else {
            System.out.println(line);
          }
        }
        }
      }
      catch (IOException e) {
        throw new RuntimeException(e);
      }
    }
    
    public void stopGivingMeAWarningProcessing(){}
  }
}

/**check if the currently set ffmpeg path is valid or set the path if 1 is provided
@return true if ffmpegExe points to a valild instalation, false if it does not but ffmpegExe now points to a platform specific location but it needs to be downloaded.
*/
boolean checkFfmpegExsists(){
  if(ffmpegExe==null || ffmpegExe.isEmpty()){
    final String linuxPath = sketchPath()+"/ffmpeg/ffmpeg";
    final String windowPath = sketchPath()+"/ffmpeg/bin/ffmpeg.exe";
    final String macosPath = sketchPath()+"/ffmpeg/ffmpeg";
    
    String thisSystemPath ="";
    
    if(platform == WINDOWS){
      thisSystemPath = windowPath;
    } else if(platform == LINUX){
      thisSystemPath = linuxPath;
    } else if(platform == MACOS){
      thisSystemPath = macosPath;
    }
    
    File exec = new File(thisSystemPath);
    ffmpegExe = thisSystemPath;
    if(exec.exists()){
      println("found ffmpeg! "+ffmpegExe);
      return true;    
    }else{
      println("ffmpeg not found!");
      return false;
    }
  }
  File exec = new File(ffmpegExe);
  if(exec.exists()){
    println("found ffmpeg! "+ffmpegExe);
    return true;
  }
  throw new RuntimeException("invlid FFMPEG path provided: "+exec.getAbsolutePath());
}

//linux extraction command
//make sure to make the ffmpeg dir first
//tar -xf ffmpeg-release-amd64-static.tar.xz -C ffmpeg --strip-components 1

/**download and extract the platform specific ffmpeg distrobution
@param progress currently unused
*/
void downloadFFMpeg(long[] progress) throws IOException {
    String link ="";
    //determine the OS specific download link for ffmpeg
    switch(platform){
      case WINDOWS:
        link = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip";
        break;
      case MACOS:
        link = "https://evermeet.cx/ffmpeg/ffmpeg-7.0.2.zip";
      default:
        link = "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz";
    }

    //dowload the file
    URL url = new URL(link);
    URLConnection c = url.openConnection();
    c.setRequestProperty("User-Agent", "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; .NET CLR 1.0.3705; .NET CLR 1.1.4322; .NET CLR 1.2.30703)");
    if(progress!=null && progress.length>=2){
      progress[0] = c.getContentLengthLong();
    }

    InputStream input;
    input = c.getInputStream();
    byte[] buffer = new byte[4096];
    int n = -1;
    //create a folder for the output to go in
    new File(sketchPath()+"/ffmpeg").mkdirs();
    
    //for windoow and mac simply pass the raw file data diretly to a zip decompressor and dave the contence on the drive
    switch(platform){
      case WINDOWS:
      case MACOS:
        ZipInputStream zis = new ZipInputStream(input);
        //maby count entries here for progress bar
        ZipEntry ze = zis.getNextEntry();
        //for each entry
        while(ze != null){
          String fileName = ze.getName();
          //modify path here to remove zip folder name
          if(fileName.split("/")[0].contains("-essentials_build")){
            fileName=fileName.substring(fileName.indexOf('/'));
          }
          File newFile = new File(sketchPath()+"/ffmpeg" + File.separator + fileName);

          //create directories for sub directories in zip
          new File(newFile.getParent()).mkdirs();
           if (ze.isDirectory()) {
               if (!newFile.isDirectory() && !newFile.mkdirs()) {
                   throw new IOException("Failed to create directory " + newFile);
               }
           } else {
             //take the current entry data and save it to the disk
              FileOutputStream fos = new FileOutputStream(newFile);
              int len;
              while ((len = zis.read(buffer)) > 0) {
                fos.write(buffer, 0, len);
              }
              fos.close();
           }
          //close this ZipEntry
          zis.closeEntry();
          ze = zis.getNextEntry();
        }
        zis.closeEntry();
        zis.close();
        break;

      
      default:
      //because linux is querky the linux verison is only distribued in a .tar.xz file, we have no eazy way of extracting that in java so we will just save it to the disk
      //then use the tar command to extract it
      
      //save the raw file data to the disk
        OutputStream output = new FileOutputStream(new File(sketchPath()+"/ffmpeg.tar.xz"));
        while ((n = input.read(buffer)) != -1) {
          if (n > 0) {
            output.write(buffer, 0, n);
            if(progress!=null && progress.length>=2){
              progress[1]+=n;
            }
          }
        }
        output.close();
        
        String[] tarCommand = {"tar","-xf",sketchPath()+"/ffmpeg.tar.xz","-C", sketchPath()+"/ffmpeg", "--strip-components", "1"};
        Process decompress = exec(tarCommand);
        while(decompress.isAlive()){
          try{
          Thread.sleep(10);
          }catch(Exception e){}
        }
    }
  }
