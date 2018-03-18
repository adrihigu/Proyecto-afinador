import processing.serial.*; 

// Variables de recepcion de datos
Serial myPort;                                                           // Puerto Serial
byte[] inBuffer= new byte[5];                                            // Bytes de entrada del puerto serial
int buffersize=1;                                                        // Tamaño del buffer de entrada
int txtSamples = 4681;                                                   // Numero de valores máximo del archivo de texto
boolean dig1=false;                                                      // Sensor digital 1
boolean dig2=false;                                                      // Sensor digital 2
boolean dig3=false;                                                      // Sensor digital 3
boolean dig4=false;                                                      // Sensor digital 4
boolean sync = false;                                                    // Indica si la comunicacion serial esta sincronizada
boolean ADC2=false;                                                      // Indica si hay datos por recibir del can//al de adquisición 2
FloatList val1Buffer = new FloatList();                                  // Guarda las medidas del micrófono tras la decodificación
float val2=0;                                                            // Cambia al valor de la medida del potenciómetro tras la decodificación
String[] txtBuffer1 = new String[txtSamples];                            // Buffer que guarda como texto las medidas del ADC1
String[] txtBuffer2 = new String[txtSamples];                            // Buffer que guarda como texto las medidas del ADC2

// Variables de osciloscopio y gráfica
PFont font;                                                              // Tipo de letra
int ls = 24;                                                             // Constante para espaciado
int numScale = 10;                                                       // Cantidad de divisiones de X e Y
int OscCount=0;                                                          // Contador de barrido
int xSet=4;                                                              // Indica el valor de la escala en X
int ySet=3;                                                              // Indica el valor de la escala en Y
int[] xScale={100, 500, 1000, 5000, 10000, 50000, 100000,500000};        // Rango de escalas de X en us
int[] yScale={50, 100, 200, 300, 500, 1000, 3000};                       // Rango de escalas de Y en mV
int xSamples, ySamples;                                                  // Numero de puntos a graficar para X e Y
float xLabel, yLabel;                                                    // Longitud de los ejes X e Y
float xLength, yLength;                                                  // Espacio entre puntos del eje X e Y
float sampleTime= 274.658;                                               // Resolución de X = Tiempo de muestreo
float sampleVolt = 0.732421875;                                          // Resolución de Y = 3000/4096 mV
boolean clear=true;                                                      // Cuando es true, dibuja el fondo del osciloscopio
boolean stop=false;                                                      // Cuando es true, deja de dibujar

// Variables de detección de tono
int dataSize = 1024;                                                     // Cantidad de datos a procesar por el algoritmo YIN
float sampleRate = 3640.89158153;                                        // Frecuencia de muestreo
PitchDetector realPitch = new Yin(sampleRate,dataSize);                  // Clase que implementa el metodo del algoritmo YIN
float myPitch;                                                           // Resultado de la detección de frecuencia
IntList pitchBuffer = new IntList();                                     // Guarda los tonos detectados en una lista

// Variables de interfaz de usuario
int refTone;                                                             // El tono asociado a la medida del potenciómetro
int refVolt = 230;                                                      // Maxima excursion de voltaje que ofrece el potenciometro
FloatList refFrec = new FloatList();                                     // Lista de las frecuencias que se usan para delimitar los tonos musicales
float xLevels = 20;                                                      // Número máximo de rectangulos en la gráfica = Resolución en X
float yLevels;                                                           // Cantidad de tonos para Resolución en Y
float rectWidth;                                                         // Ancho de rectángulos
float rectHeight;                                                        // Alto de rectángulos
String down = "02C5";                                                    // Caracter Unicode. Flecha hacia abajo
String up = "02C4";                                                      // Caracter Unicode. Flecha hacia arriba
 
void setup(){
  size(800,500);                                                         // Inicializa el tamaño de la ventana
  printArray(Serial.list());                                             // Muestra los puertos seriales disponibles
  myPort = new Serial(this, Serial.list()[0], 115200);                   // Inicializa el puerto usado para recepción serial
  myPort.buffer(buffersize);                                             // Ajusta el tamaño del buffer serial, por defecto 1
  initRefFrec();                                                         // Inicializa el vector de las frecuencias que se usan para delimitan los tonos musicales 
  yLevels = refFrec.size();                                              // Inicializa el valor de la variable yLevels
  initDraw();                                                            // Inicializa fuentes de texto, carácteres especiales y variables para graficar
}

void draw() {
  //oscilloscope();
  if(!isStop()){                                                          // Si no está en pausa...
    if(val1Buffer.size() > dataSize - 1){                                 // Si hay suficientes datos para el algoritmo en el buffer de audio...
      myPitch = (realPitch.getPitch(val1Buffer.array())).getPitch();      // Calcula de la frecuencia fudamental con el algoritmo YIN
      val1Buffer.clear();                                                 // Limpia los valores del buffer de audio
      pitchBuffer.append(frec2tone(myPitch));                             // Añade el tono musical asociado a la frecuencia determinada en el buffer de tonos
      println("DETECTADO: "+ myPitch + ". TONO: " + frec2tone(myPitch));  
      background(0);                                                      // Borra el fondo de la interface
      drawTunner();                                                       // Dibuja la parte que indica diferencia con respecto al tono deseado
      drawText();                                                         // Dibuja el nombre de los tonos del tono recibido y el de referencia
      drawGraph();                                                        // Dibuja el grafico de los tonos que se han captado recientemente y la altura de la barra de referencia
     
      if(pitchBuffer.size() > xLevels - 1){                               // Limita el tamaño del buffer de tonos
        pitchBuffer.remove(0);
      }
    }
  }
}
 
void serialEvent(Serial myPort) { 
  // Lectura del buffer de entrada
  myPort.readBytes(inBuffer);
  
  // Verifica si el buffer está sincronizado
  syncronize();
  
  if(sync && inBuffer[0] >= 0){  
  // Inicia decodificación del protocolo para la señal del microfono (ADC1)
    if(val1Buffer.size() < dataSize){
      val1Buffer.append(decodeADC1());
    } 
  // Inicia decodificación del protocolo para la señal del potenciómetro (ADC2)
    if(ADC2){
      val2 = decodeADC2();
      println(val2);
      ADC2=false;
    }
  // Guardado de las variables en archivos de texto para visualización
  //storeOnTxt("FAKEmuest500");
  }
  
  if(sync){  
    nextHeaderRead();
  }
  
  myPort.buffer(buffersize);
}

//*********************************************** RECEPCION DE DATOS ***************************************************//
  //
  // Función que cambia la bandera sync cuando encuetra el encabezado del siguiente bloque
void syncronize(){
  if(!sync){
    if(inBuffer[0] < 0){
      sync=true;
    }
  }
}

  //
  // Funcion que decodifica los bytes asignados al ADC1 en el protocolo y guarda el valor en va1
int decodeADC1(){
  int var1;
  // Lectura del sensor digital 1
  var1=inBuffer[0] & 0x40;            
  if(var1==64){
    dig1=false;
  }
  if(var1==0){
    dig1=true;
  }
  
  // Lectura del sensor digital 2
  var1=inBuffer[0] & 0x20;
  if(var1==32){
    dig2=false;
  }
  if(var1==0){
    dig2=true;
  }
  
  // Lectura del sensor analógico 1
  var1 = (((inBuffer[0] & 0x1F) << 7) + inBuffer[1]);
  return var1;
}

  //
  // Funcion que decodifica los bytes asignados al ADC2 en el protocolo y guarda el valor en val2
int decodeADC2(){
  int var2;
  // Lectura del sensor digital 3
  var2=inBuffer[2] & 0x40;            
  if(var2==64){
    dig3=false;
  }
  if(var2==0){
    dig3=true;
  }
  
  // Lectura del sensor digital 4
  var2=inBuffer[2] & 0x20;
  if(var2==32){
    dig4=false;
  }
  if(var2==0){
    dig4=true;
  }
  
  // Lectura del sensor analógico 1
  var2 = (((inBuffer[2] & 0x1F) << 7) + inBuffer[3]);
  return var2;
}

  //
  // Guardado de txtSample muestras en archivos de texto, uno para la señal del microfono y otro para la del potenciómetro
void storeOnTxt(String name){
  int i = 0;
  if(i<txtSamples){
    txtBuffer1[i]=str(decodeADC1());
    txtBuffer2[i]=str(decodeADC2());
    i++;
  }
  else{
    saveStrings(name + ".txt", txtBuffer1);
    // saveStrings("POTENCIOMETRO.txt", txtBuffer2);
    txtBuffer1 = new String[txtSamples];
    txtBuffer2 = new String[txtSamples];
    myPort.stop();
  } 
}

  //
  // Función que asigna el tamaño del buffer, bufferSize, de acuerdo al encabezado del siguiente bloque
void nextHeaderRead(){
  switch(inBuffer[buffersize-1]){
    case -15:
      buffersize=3;
      break;
    case -14:
      buffersize=5;
      ADC2=true;
      break;
    default:
      sync=false;
      buffersize=1;
      break;
    }
}

//*********************************************** OSCILOSCOPIO ***************************************************//
void oscilloscope(){
  if(!stop){
    if(clear){
      drawGrid();
      val1Buffer.clear();
      OscCount = 0;
      clear=false;
    }
    if(val1Buffer.size() != 0){
      plot(val1Buffer.get(0));
      val1Buffer.remove(0);
    }
  }
}
  //
  // Ploteo
void drawGrid(){
  background(255);
  for(int i=0;i<numScale;i++){
    stroke(200);
    line(2*ls,height - 2*ls -(i+1)*(yLabel/numScale),2*ls + xLabel,height - 2*ls -(i+1)*(yLabel/numScale));  // Linea horizontal
    line(2*ls + (i+1)*(xLabel/numScale),height - 2*ls ,2*ls + (i+1)*(xLabel/numScale),2*ls);  // Linea horizontal
  }
  stroke(0);
  line(2*ls, 2*ls, 2*ls, height -2*ls); // xlabel
  line(2*ls, height- 2*ls, width - 2*ls, height- 2*ls); // ylabel
  fill(100);
  text("Escala X: "+ xScale[xSet] + "us", 2*ls, height -ls);
  text("Escala Y: "+ yScale[ySet] + "mV", 3*ls + textWidth("Escala X: "+ xScale[xSet] + "us") , height -ls);
  
  xSamples = int(numScale*xScale[xSet]/sampleTime);
  xLength = xLabel/xSamples;
  ySamples= int(numScale*yScale[ySet]/sampleVolt);
  yLength= yLabel/ySamples;
}

void  plot(float var){
  float preVar=0;
  stroke(255,0,0);
  if((OscCount < xSamples) && (OscCount != 0)){
    line(2*ls + (OscCount-1) * xLength, height -2*ls - preVar * yLength, 2*ls + OscCount * xLength, height -2*ls - var * yLength);
  }
  
  if(OscCount >= xSamples){
    clear = true;
  }
  
  preVar = var;
  OscCount++;
}

void keyPressed(){
    if(key == CODED){
      switch(keyCode){
        case RIGHT:
          if(xSet!=xScale.length-1)
            xSet++;
          break;
        case LEFT:
          if(xSet!=0)
            xSet--;
          break;
        case UP:
          if(ySet!=yScale.length-1)
            ySet++;
          break;
        case DOWN:
          if(ySet!=0)
            ySet--;
          break;
      }
      clear = true;
    }
    if(key == 32)
      stop = !stop;  
}
//*********************************************** INTERFAZ DE USUARIO ***************************************************//

void drawTunner(){
  refTone = volt2tone(val2);
  
  if(pitchBuffer.get(pitchBuffer.size()-1) > refTone){
    fill(255, 0, 0);
    text(down, width -2*ls - textWidth(down), ls);
    text("Por encima de la nota...",width -2*ls - (textWidth("Por encima de la nota...") + textWidth(down))/2, 2*ls);
  }
  if(pitchBuffer.get(pitchBuffer.size()-1) == refTone){
    fill(0, 255, 0);
    text(down, width -2*ls - textWidth(down), ls);
    text("¡En la nota!",width -2*ls - (textWidth("¡En la nota!") + textWidth(up))/2, 2*ls);
    text(up, width -2*ls - textWidth(up), 3*ls);
  }
  if(pitchBuffer.get(pitchBuffer.size()-1) < refTone){
    fill(255, 0, 0);
    text(up, width -2*ls - textWidth(up), 3*ls);
    text("Por debajo de la nota...",width -2*ls - (textWidth("Por debajo de la nota...") + textWidth(up))/2, 2*ls);
  }
}

void drawGraph(){
  stroke(255);
  textSize(rectWidth/3);
  for(int i = pitchBuffer.size()-1; i >= 0; i--){
    rectHeight = pitchBuffer.get(i) * yLength/yLevels;
    fill(0);
    rect((width-2*ls) - ((pitchBuffer.size()-i)) * rectWidth, (height -2*ls -1) - rectHeight, rectWidth, rectHeight,2);
    fill(255);
    text(toneName(pitchBuffer.get(pitchBuffer.size()-(i+1))),(width-2*ls) - (i+1) * rectWidth,(height -2*ls -1) + ls);
}
  fill(0);
  textSize(16);
  if(pitchBuffer.get(pitchBuffer.size()-1) == refTone){
    stroke(0,255,0);
  }
  else{
    stroke(255,0,0);
  }
  fill(255);
  text(toneName(pitchBuffer.get(pitchBuffer.size()-1)),width-ls, (height -2*ls -1) - rectHeight);                    // Nombre del tono actual
  rect(2*ls, height -2*ls - pitchBuffer.get(pitchBuffer.size()-1) * yLength/yLevels - 1, xLength, yLength/yLevels);  // Linea de referencia
  rect(2*ls, height -2*ls - refTone * yLength/yLevels - 1, xLength, yLength/yLevels);                                // Linea de tono captado 
}

void drawText(){
  fill(255);
  text("Tono captado: ",10,ls);
  text(toneName(pitchBuffer.get(pitchBuffer.size()-1)),10+textWidth("Tono captado: "),ls);
  
  text("Frecuencia: ",10,2*ls);
  text(myPitch,10+textWidth("Frecuencia: "),2*ls);
  
  text("Tono de referencia: ",10,3*ls);
  text(toneName(refTone),10+textWidth("Tono de referencia: "),3*ls); // FALTA TONO REFERENCIA
}

void initRefFrec(){
  int tone = 1;
  int oct = 0;
  while(tone <= 12 && oct <= 5){
    refFrec.append( (frec(tone-1,oct) + frec(tone,oct))/2 );
    tone++;
    if(tone > 12){
      oct++;
      tone = 1;
    }
  }
}

void initDraw(){
  int n;
  char[] chars;
  
  font = createFont("Tahoma",20,true);
  textFont(font,16);
  
  xLength = width - 4*ls;
  yLength = height - 6*ls;
  
  rectWidth = xLength/xLevels;
  n = unhex(down);
  chars = Character.toChars(n);
  down = new String(chars);
  down = down + " " + down + " " + down + " " + down + " " + down + " " + down + " " + down + " " + down + " " + down + " " + down + " " + down ;
  
  n = unhex(up);
  chars = Character.toChars(n);
  up = new String(chars);
  up = up + " " + up + " " + up + " " + up + " " + up + " " + up + " " + up + " " + up + " " + up + " " + up+ " " + up;

}

float frec(float tone, float oct){
  return(440 * exp( ((oct-3) + (tone-10)/12) * log(2)));
}

int frec2tone(float pitchFrec){
  for(int i=0; i < refFrec.size() -1; i++){
    if((pitchFrec >= refFrec.get(i)) && (pitchFrec <= refFrec.get(i+1))){
      return i+1;
    }
  }
  return -1;
}

int volt2tone(float pitchVolt){
  for(int i=0; i < refFrec.size() -1; i++){
    if((pitchVolt >= (refVolt/refFrec.size())*i) && (pitchVolt <= (refVolt/refFrec.size())*(i+1))){
      return i+1;
    }
  }
  return -1;
}

boolean isStop(){
  boolean preStop1=false;
  boolean preStop2=false;
  boolean preStop3=false;
  boolean preStop4=false;
  
  if(preStop1 == true && dig1 == false){
    stop=!stop;
  }

  if(preStop2 == true && dig2 == false){
    stop=!stop;
  }
    
  if(preStop3 == true && dig3 == false){
    stop=!stop;
  }
    
  if(preStop4 == true && dig4 == false){
    stop=!stop;
  }
  
  preStop1 = dig1;
  preStop2 = dig2;
  preStop3 = dig3;
  preStop4 = dig4;
  
  return stop;
}


String toneName(int pitch){
  int tone=-1;
  int oct=-1;
  String name = "";
  tone = pitch % 12;
  oct=1 + (pitch/12);
  switch(tone){
    case 0:
      name = name + "Si";
      oct--;
      break;
    case 1:
      name = name + "Do";
      break;
    case 2:
      name = name + "Do#";
      break;
    case 3:
      name = name + "Re";
      break;
    case 4:
      name = name + "Re#";
      break;
    case 5:
      name = name + "Mi";
      break;
    case 6:
      name = name + "Fa";
      break;
    case 7:
      name = name + "Fa#";
      break;
    case 8:
      name = name + "Sol";
      break;
    case 9:
      name = name + "Sol#";
      break;
    case 10:
      name = name + "La";
      break;
    case 11:
      name = name + "La#";
      break;
    case 12:
      name = name + "Si";
      break;
    default:
      println("ERROR: No pitch name: " + pitch);
      return "???";
  }
  return name + oct;
}
//*********************************************** DETECCION DE TONO ***************************************************//

public class PitchDetectionResult {  
  /**
   * The pitch in Hertz.
   */
  private float pitch;
  
  private float probability;
  
  private boolean pitched;
  
  public PitchDetectionResult(){
    pitch = -1;
    probability = -1;
    pitched = false;
  }
  
  /**
   * A copy constructor. Since PitchDetectionResult objects are reused for performance reasons, creating a copy can be practical.
   * @param other
   */
  public PitchDetectionResult(PitchDetectionResult other){
    this.pitch = other.pitch;
    this.probability = other.probability;
    this.pitched = other.pitched;
  }
     
  
  /**
   * @return The pitch in Hertz.
   */
  public float getPitch() {
    return pitch;
  }

  public void setPitch(float pitch) {
    this.pitch = pitch;
  }
  
  /* (non-Javadoc)
   * @see java.lang.Object#clone()
   */
  public PitchDetectionResult clone(){
    return new PitchDetectionResult(this);
  }

  /**
   * @return A probability (noisiness, (a)periodicity, salience, voicedness or
   *         clarity measure) for the detected pitch. This is somewhat similar
   *         to the term voiced which is used in speech recognition. This
   *         probability should be calculated together with the pitch. The
   *         exact meaning of the value depends on the detector used.
   */
  public float getProbability() {
    return probability;
  }

  public void setProbability(float probability) {
    this.probability = probability;
  }

  /**
   * @return Whether the algorithm thinks the block of audio is pitched. Keep
   *         in mind that an algorithm can come up with a best guess for a
   *         pitch even when isPitched() is false.
   */
  public boolean isPitched() {
    return pitched;
  }

  public void setPitched(boolean pitched) {
    this.pitched = pitched;
  }  
}
/////////////////////////////////////////////////////////////////////////

public interface PitchDetector {
  /**
   * Analyzes a buffer with audio information and estimates a pitch in Hz.
   * Currently this interface only allows one pitch per buffer.
   * 
   * @param audioBuffer
   *            The buffer with audio information. The information in the
   *            buffer is not modified so it can be (re)used for e.g. FFT
   *            analysis.
   * @return An estimation of the pitch in Hz or -1 if no pitch is detected or
   *         present in the buffer.
   */
  PitchDetectionResult getPitch(final float[] audioBuffer);
}
/////////////////////////////////////////////////////////////////////////

public final class Yin implements PitchDetector {
  /**
   * The default YIN threshold value. Should be around 0.10~0.15. See YIN
   * paper for more information.
   */
  private static final double DEFAULT_THRESHOLD = 0.20;

  /**
   * The default size of an audio buffer (in samples).
   */
  public static final int DEFAULT_BUFFER_SIZE = 2048;

  /**
   * The default overlap of two consecutive audio buffers (in samples).
   */
  public static final int DEFAULT_OVERLAP = 1536;

  /**
   * The actual YIN threshold.
   */
  private final double threshold;

  /**
   * The audio sample rate. Most audio has a sample rate of 44.1kHz.
   */
  private final float sampleRate;

  /**
   * The buffer that stores the calculated values. It is exactly half the size
   * of the input buffer.
   */
  private final float[] yinBuffer;
  
  /**
   * The result of the pitch detection iteration.
   */
  private final PitchDetectionResult result;

  /**
   * Create a new pitch detector for a stream with the defined sample rate.
   * Processes the audio in blocks of the defined size.
   * 
   * @param audioSampleRate
   *            The sample rate of the audio stream. E.g. 44.1 kHz.
   * @param bufferSize
   *            The size of a buffer. E.g. 1024.
   */
  public Yin(final float audioSampleRate, final int bufferSize) {
    this(audioSampleRate, bufferSize, DEFAULT_THRESHOLD);
  }

  /**
   * Create a new pitch detector for a stream with the defined sample rate.
   * Processes the audio in blocks of the defined size.
   * 
   * @param audioSampleRate
   *            The sample rate of the audio stream. E.g. 44.1 kHz.
   * @param bufferSize
   *            The size of a buffer. E.g. 1024.
   * @param yinThreshold
   *            The parameter that defines which peaks are kept as possible
   *            pitch candidates. See the YIN paper for more details.
   */
  public Yin(final float audioSampleRate, final int bufferSize, final double yinThreshold) {
    this.sampleRate = audioSampleRate;
    this.threshold = yinThreshold;
    yinBuffer = new float[bufferSize / 2];
    result = new PitchDetectionResult();
  }

  /**
   * The main flow of the YIN algorithm. Returns a pitch value in Hz or -1 if
   * no pitch is detected.
   * 
   * @return a pitch value in Hz or -1 if no pitch is detected.
   */
  public PitchDetectionResult getPitch(final float[] audioBuffer) {

    final int tauEstimate;
    final float pitchInHertz;

    // step 2
    difference(audioBuffer);

    // step 3
    cumulativeMeanNormalizedDifference();

    // step 4
    tauEstimate = absoluteThreshold();

    // step 5
    if (tauEstimate != -1) {
      final float betterTau = parabolicInterpolation(tauEstimate);

      // step 6
      // TODO Implement optimization for the AUBIO_YIN algorithm.
      // 0.77% => 0.5% error rate,
      // using the data of the YIN paper
      // bestLocalEstimate()

      // conversion to Hz
      pitchInHertz = sampleRate / betterTau;
    } else{
      // no pitch found
      pitchInHertz = -1;
    }
    
    result.setPitch(pitchInHertz);

    return result;
  }

  /**
   * Implements the difference function as described in step 2 of the YIN
   * paper.
   */
  private void difference(final float[] audioBuffer) {
    int index, tau;
    float delta;
    for (tau = 0; tau < yinBuffer.length; tau++) {
      yinBuffer[tau] = 0;
    }
    for (tau = 1; tau < yinBuffer.length; tau++) {
      for (index = 0; index < yinBuffer.length; index++) {
        delta = audioBuffer[index] - audioBuffer[index + tau];
        yinBuffer[tau] += delta * delta;
      }
    }
  }

  /**
   * The cumulative mean normalized difference function as described in step 3
   * of the YIN paper. <br>
   * <code>
   * yinBuffer[0] == yinBuffer[1] = 1
   * </code>
   */
  private void cumulativeMeanNormalizedDifference() {
    int tau;
    yinBuffer[0] = 1;
    float runningSum = 0;
    for (tau = 1; tau < yinBuffer.length; tau++) {
      runningSum += yinBuffer[tau];
      yinBuffer[tau] *= tau / runningSum;
    }
  }

  /**
   * Implements step 4 of the AUBIO_YIN paper.
   */
  private int absoluteThreshold() {
    // Uses another loop construct
    // than the AUBIO implementation
    int tau;
    // first two positions in yinBuffer are always 1
    // So start at the third (index 2)
    for (tau = 2; tau < yinBuffer.length; tau++) {
      if (yinBuffer[tau] < threshold) {
        while (tau + 1 < yinBuffer.length && yinBuffer[tau + 1] < yinBuffer[tau]) {
          tau++;
        }
        // found tau, exit loop and return
        // store the probability
        // From the YIN paper: The threshold determines the list of
        // candidates admitted to the set, and can be interpreted as the
        // proportion of aperiodic power tolerated
        // within a periodic signal.
        //
        // Since we want the periodicity and and not aperiodicity:
        // periodicity = 1 - aperiodicity
        result.setProbability(1 - yinBuffer[tau]);
        break;
      }
    }

    
    // if no pitch found, tau => -1
    if (tau == yinBuffer.length || yinBuffer[tau] >= threshold) {
      tau = -1;
      result.setProbability(0);
      result.setPitched(false);  
    } else {
      result.setPitched(true);
    }

    return tau;
  }

  /**
   * Implements step 5 of the AUBIO_YIN paper. It refines the estimated tau
   * value using parabolic interpolation. This is needed to detect higher
   * frequencies more precisely. See http://fizyka.umk.pl/nrbook/c10-2.pdf and
   * for more background
   * http://fedc.wiwi.hu-berlin.de/xplore/tutorials/xegbohtmlnode62.html
   * 
   * @param tauEstimate
   *            The estimated tau value.
   * @return A better, more precise tau value.
   */
  private float parabolicInterpolation(final int tauEstimate) {
    final float betterTau;
    final int x0;
    final int x2;

    if (tauEstimate < 1) {
      x0 = tauEstimate;
    } else {
      x0 = tauEstimate - 1;
    }
    if (tauEstimate + 1 < yinBuffer.length) {
      x2 = tauEstimate + 1;
    } else {
      x2 = tauEstimate;
    }
    if (x0 == tauEstimate) {
      if (yinBuffer[tauEstimate] <= yinBuffer[x2]) {
        betterTau = tauEstimate;
      } else {
        betterTau = x2;
      }
    } else if (x2 == tauEstimate) {
      if (yinBuffer[tauEstimate] <= yinBuffer[x0]) {
        betterTau = tauEstimate;
      } else {
        betterTau = x0;
      }
    } else {
      float s0, s1, s2;
      s0 = yinBuffer[x0];
      s1 = yinBuffer[tauEstimate];
      s2 = yinBuffer[x2];
      // fixed AUBIO implementation, thanks to Karl Helgason:
      // (2.0f * s1 - s2 - s0) was incorrectly multiplied with -1
      betterTau = tauEstimate + (s2 - s0) / (2 * (2 * s1 - s2 - s0));
    }
    return betterTau;
  }
}
