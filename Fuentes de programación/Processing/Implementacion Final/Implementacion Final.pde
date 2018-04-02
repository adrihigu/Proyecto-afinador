import processing.serial.*;
public static final int NONE = 0;
public static final int HOLD = 1;
public static final int GUITAR = 2;
public static final int VIOLIN = 3;

// Variables de recepcion de datos
Serial myPort;                                                           // Puerto Serial
byte[] inBuffer= new byte[5];                                            // Bytes de entrada del puerto serial
int buffersize=1;                                                        // Tamaño del buffer de entrada
boolean dig1=false;                                                      // Sensor digital 1
boolean dig2=false;                                                      // Sensor digital 2
boolean dig3=false;                                                      // Sensor digital 3
boolean dig4=false;                                                      // Sensor digital 4
boolean preDig=false;                                                    // Lectura anterior del sensor digital
boolean sync = false;                                                    // Indica si la comunicacion serial esta sincronizada
boolean ADC2=false;                                                      // Indica si hay datos por recibir del can//al de adquisición 2
FloatList val1Buffer = new FloatList();                                  // Guarda las medidas del micrófono tras la decodificación
FloatList val2Buffer = new FloatList();                                  // Guarda valor de la medida del potenciómetro tras la decodificación
 
// Variables de detección de tono
int dataSize = 512;                                                     // Cantidad de datos a procesar por el algoritmo YIN
int refSize = int(dataSize/60) + 1;                                      // Cantidad de muestras para referencia del potenciómetro
float sampleRate = 3640.89158153;                                        // Frecuencia de muestreo
PitchDetector realPitch = new Yin(sampleRate,dataSize);                  // Clase que implementa el metodo del algoritmo YIN
float myPitch;                                                           // Resultado de la detección de frecuencia
IntList pitchBuffer = new IntList();                                     // Guarda los tonos detectados

// Variables de interfaz de usuario
PFont font;                                                              // Tipo de letra
int ls = 24;                                                             // Constante para espaciado
int[] refTone = new int[1];                                              // El tono asociado a la medida del potenciómetro
int refVolt = 2350;                                                       // Maxima excursion de voltaje que ofrece el potenciometro
int mode;                                                                // Modo de operacion del afinador
int holdTone;                                                            // Tono mantenido para el modo HOLD
int[] guitar= {17,22,27,32,36,41};                                       // Tono de las cuerdas de la guitarra (E2, A2, D3, G3, B3, E4)
int[] violin= {20,27,34,17};                                             // Tono de las cuerdas de la guitarra (G2, D3, A3, E2)
FloatList refFrec = new FloatList();                                     // Lista de las frecuencias que se usan para delimitar los tonos musicales
float xLevels = 50;                                                      // Número máximo de rectangulos en la gráfica = Resolución en X
float yLevels;                                                           // Cantidad de tonos = Resolución en Y
float rectWidth;                                                         // Ancho de rectángulos
float rectHeight;                                                        // Alto de rectángulos
String modeMsg = "";                                                     // Mensaje del modo de operación
String down = "02C5";                                                    // Caracter Unicode. Flecha hacia abajo
String up = "02C4";                                                      // Caracter Unicode. Flecha hacia arriba
boolean stop=false;                                                      // Cuando es true, deja de dibujar
float xLabel, yLabel;                                                    // Longitud de los ejes X e Y
float xLength, yLength;                                                  // Espacio entre puntos del eje X e Y

void setup(){
  size(1024,700);                                                        // Inicializa el tamaño de la ventana
  printArray(Serial.list());                                             // Muestra los puertos seriales disponibles
  myPort = new Serial(this, Serial.list()[0], 115200);                   // Inicializa el puerto usado para recepción serial
  myPort.buffer(buffersize);                                             // Ajusta el tamaño del buffer serial, por defecto 1
  initRefFrec();                                                         // Inicializa el vector de las frecuencias que se usan para delimitan los tonos musicales
  yLevels = refFrec.size();                                              // Inicializa el valor de la variable yLevels
  initDraw();                                                            // Inicializa fuentes de texto, carácteres especiales y variables para graficar
}

void draw() {
  if(!stop){                                                              // Si no está en pausa...
    if(val1Buffer.size() >= dataSize){                                    // Si hay suficientes datos para el algoritmo en el buffer de audio...
      myPitch = (realPitch.getPitch(val1Buffer.array())).getPitch();      // Calcula de la frecuencia fudamental con el algoritmo YIN
      val1Buffer.clear();                                                 // Limpia los valores del buffer de audio
      pitchBuffer.append(frec2tone(myPitch));                             // Añade el tono musical asociado a la frecuencia determinada en el buffer de tonos
      background(0);                                                      // Borra el fondo de la interface
      drawPitch();                                                        // Dibuja el grafico de los tonos que se han captado recientemente y la altura de la barra de referencia
      drawRef();                                                          // Dibuja la parte que indica diferencia con respecto al tono deseado
      drawText();                                                         // Dibuja el nombre de los tonos del tono recibido y el de referencia
      if(pitchBuffer.size() > xLevels - 1){                               // Limita el tamaño del buffer de tonos
        pitchBuffer.remove(0);
      }
    }
  }
  if(stop){
    text(modeMsg + " (PAUSA)",10+textWidth("Modo de operación: "),3*ls);  // Indica el modo de operación y "(PAUSA)"
  }
  else{
    text(modeMsg,10+textWidth("Modo de operación: "),3*ls);               // Indica el modo de operación
  }
}

//*********************************************** RECEPCION DE DATOS ***************************************************//
 
void serialEvent(Serial myPort) { 
  myPort.readBytes(inBuffer);                // Lectura del buffer de entrada
  syncronize();                              // Verifica si el buffer está sincronizado
  if(sync && inBuffer[0] >= 0){              // Si hay sincronizacion y si no se está leyendo un encabezado...
    if(val1Buffer.size() < dataSize){        // Si hay menos datos en el buffer de los necesarios para el algoritmo YIN...
      val1Buffer.append(decodeChannel1());   // Decodifica la señal del microfono y guarda el valor en una lista
    } 
    if(ADC2){                                // Si se ha recibido datos del segundo canal del ADC...
      val2Buffer.append(decodeChannel2());   // Decodifica la señal del potenciometro y guarda el valor en una lista
      while(val2Buffer.size() > refSize){    // Si hay más datos de los necesarios para hacer el promedio...
        val2Buffer.remove(0);                // Elimina el elemento más antiguo del buffer para valores del segundo canal
      }
      ADC2=false;                            // Cambia estado a inactivo
      println("val2 = " + val2Buffer.get(val2Buffer.size()-1));
    }
  }
  if(sync){                                  // Si hay sincronización...
    readNextHeader();                        // Lee el encabezado del siguiente bloque
  }
  myPort.buffer(buffersize);                 // Cambia el tamaño del buffer de recepción para el siguiente bloque de bytes
}

  /**
   * Comprueba si la recepción serial está sincronizada          
   * 
   */
void syncronize(){
  if(!sync){
    if(inBuffer[0] < 0){
      sync=true;
    }
  }
}
  /**
   * 
   * retorna valor de la medida del primer canal analógico sin el protocolo y asigna modo de operación de acuerdo
   * valor de los sensores digitales 1 y 2
   */
int decodeChannel1(){
  preDig = dig1;
  if((inBuffer[0] & 0x40) == 64){
    dig1=false;
  }
  if((inBuffer[0] & 0x40) == 0){
    dig1=true;
  }
  if(preDig == false && dig1 == true){
    switch(mode){
      case NONE:
        mode = HOLD;
        holdTone = refTone[0];
        break;
      case HOLD:
        mode = NONE;
        break;
      default:
        break;
    }
  }
  
  preDig = dig2;
  if((inBuffer[0] & 0x20) == 32){
    dig2=false;
  }
  if((inBuffer[0] & 0x20) == 0){
    dig2=true;
  }
  if(preDig == false && dig2 == true){
    switch(mode){
      case NONE:
        mode = GUITAR;
        break;
      case GUITAR:
        mode = NONE;
        break;
      default:
        break;
    }
  }
  return (((inBuffer[0] & 0x1F) << 7) + inBuffer[1]);
}

  /**
   * 
   * retorna valor de la medida del segundo canal analógico sin el protocolo y asigna modo de operación de acuerdo
   * valor de los sensores digitales 3 y 4
   */
int decodeChannel2(){ 
  preDig = dig3;
  if((inBuffer[2] & 0x40)==64){
    dig3=false;
  }
  if((inBuffer[2] & 0x40)==0){
    dig3=true;
  }
  if(preDig == false && dig3 == true){
    switch(mode){
      case NONE:
        mode = VIOLIN;
        break;
      case VIOLIN:
        mode = NONE;
        break;
      default:
        break;
    }
  }
  
  preDig = dig4;
  if((inBuffer[2] & 0x20)==32){
    dig4=false;
  }
  if((inBuffer[2] & 0x20)==0){
    dig4=true;
  }
  if(preDig == false && dig4 == true){
    stop = !stop;
  }
  return (((inBuffer[2] & 0x1F) << 7) + inBuffer[3]);
}

  /**
   * 
   * Asigna el tamaño del buffer para la lectura del siguiente bloque de acuerdo al tipo de encabezado (0xF1, 0xF2).
   * Habilita la lectura del segundo canal analogico y detecta si hay desincronizacion.
   */
void readNextHeader(){
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

//*********************************************** INTERFAZ DE USUARIO ***************************************************//

  /**
   * 
   * Dibuja el grafico de barras verticales asociado a los tonos captados anteriormente.
   * Dibuja la barra horizontal de que indica el tono captado más recientemente y su nombre a la derecha.
   */
void drawPitch(){
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
  if(pitchBuffer.get(pitchBuffer.size()-1) == refTone[0]){
    stroke(0,255,0);
  }
  else{
    stroke(255,0,0);
  }
  rectHeight = pitchBuffer.get(pitchBuffer.size() - 1) * yLength/yLevels;
  fill(255);                    // OJO: queremos rectHeight = pitchBuffer.get(pitchBuffer.size() - 1) * yLength/yLevels;
  text(toneName(pitchBuffer.get(pitchBuffer.size()-1)), width-textWidth(toneName(pitchBuffer.get(pitchBuffer.size()-1))), (height -2*ls -1) - rectHeight);          // Nombre del tono de audio actual
  rect(2*ls, height -2*ls - pitchBuffer.get(pitchBuffer.size()-1) * yLength/yLevels - 1, xLength, yLength/yLevels);                                                   // Linea de tono captado
}
 
  /**
   * 
   * Determina el tono de referencia de acuerdo al modo seleccionado por el usuario.
   * Dibuja las barras de referencia de acuerdo al modo de operación y su nombre a la izquierda.
   */
void drawRef(){
  refTone[0] = 0;
  switch(mode){
    case NONE:
      for(int i = 0; i < val2Buffer.size() - 1; i++){
        refTone[0] += val2Buffer.get(i);
      }
      refTone[0] = volt2tone(refTone[0]/val2Buffer.size());   
      displayRef(refTone);
      break;
    case HOLD:
      refTone[0] = holdTone;
      displayRef(refTone);
      break;
    case GUITAR:
      displayRef(guitar);
      break;
    case VIOLIN:
      displayRef(violin);
      break;
  }
}

  /**
   * 
   * Dibuja texto que indica si se está por encima, por debajo o en el tono de referencia.
   */
void drawText(){
  fill(255);
  text("Tono captado: ",10,ls);
  text(toneName(pitchBuffer.get(pitchBuffer.size()-1)),10 + textWidth("Tono captado: "),ls);
  
  text("Tono de referencia: ",10,2*ls);
  text(toneName(refTone[0]),10+textWidth("Tono de referencia: "),2*ls);

  text("Modo de operación: ",10,3*ls);  
  switch(mode){
    case NONE:
      modeMsg = "Dinámico";
      break;
    case HOLD:
      modeMsg = "Estático";
      break;
    case GUITAR:
      modeMsg = "Guitarra";
      break;
    case VIOLIN:
      modeMsg = "Violín";
      break;
  }
    
  if(pitchBuffer.get(pitchBuffer.size()-1) > refTone[0]){
    fill(255, 0, 0);
    text(down, width -2*ls - textWidth(down), ls);
    text("Por encima de la nota...",width -2*ls - (textWidth("Por encima de la nota...") + textWidth(down))/2, 2*ls);
  }
  if(pitchBuffer.get(pitchBuffer.size()-1) == refTone[0]){
    fill(0, 255, 0);
    text(down, width -2*ls - textWidth(down), ls);
    text("¡En la nota!",width -2*ls - (textWidth("¡En la nota!") + textWidth(up))/2, 2*ls);
    text(up, width -2*ls - textWidth(up), 3*ls);
  }
  if(pitchBuffer.get(pitchBuffer.size()-1) < refTone[0]){
    fill(255, 0, 0);
    text(up, width -2*ls - textWidth(up), 3*ls);
    text("Por debajo de la nota...",width -2*ls - (textWidth("Por debajo de la nota...") + textWidth(up))/2, 2*ls);
  }
}

  /**
   * 
   * Inicializa la lista de frecuencias que delimitan el criterio de desición para escojer un tono en particular.
   */
void initRefFrec(){
  int tone = 1;
  int oct = 0;
  while(tone <= 12 && oct <= 5){
    refFrec.append((frec(tone-1,oct) + frec(tone,oct))/2 );
    tone++;
    if(tone > 12){
      oct++;
      tone = 1;
    }
  }
}

  /**
   * 
   * Inicializa la fuente del texto, la longitud de los ejes, ancho de los rectangulos del grafico y caracteres UNICODE usados
   */
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

  /**
   * 
   * Retorna la frecuencia asociada del tono en su octava.
   * tone: Toma valores del 1 al 12. Representan DO, DO#, RE, RE#, MI, FA, FA#, SOL, SOL#, LA, LA#, SI.
   * oct: Toma valores del 1 al 5. Octava en la que se ubica el tono.
   */
float frec(float tone, float oct){
  return(440 * exp( ((oct-3) + (tone-10)/12) * log(2)));
}

  /**
   * 
   * Retorna entero que representa el tono asociado a la frecuencia recibida
   * pitchFrec: frecuencia detectada del primer canal analógico (Micrófono)
   */
int frec2tone(float pitchFrec){
  for(int i=0; i < refFrec.size() -1; i++){
    if((pitchFrec >= refFrec.get(i)) && (pitchFrec <= refFrec.get(i+1))){
      return i+1;
    }
  }
  return -1;
}

  /**
   * Retorna entero que representa el tono asociado al voltaje de referencia recibido
   * pitchVolt: voltaje detectado del segundo canal analógico (Potenciómetro)
   */
int volt2tone(float pitchVolt){
  for(int i=0; i < refFrec.size() -1; i++){
    if((pitchVolt >= (refVolt/refFrec.size())*i) && (pitchVolt <= (refVolt/refFrec.size())*(i+1))){
      return i+1;
    }
  }
  return -1;
}

  /**
   * 
   * Retorna string con el nombre del tono musical en su octava, ò "???" si no se reconoce.
   * pitch: tono cuyo nombre se desea obtener
   */
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
      return "???";
  }
  return name + oct;
}

  /**
   * 
   * Dibuja las barras de referencia en el gráfico de tonos captados y su nombre.
   * lines: arreglo cuyos elementos indican la altura de cada barra de referencia.
   */
void displayRef(int[] lines){
  for(int i = 0; i < lines.length; i++){
    if(pitchBuffer.get(pitchBuffer.size()-1) == lines[i]){
      stroke(0,255,0);
    }
    else{
      stroke(0,0,255);
    }
    fill(255);
    rect(2*ls, height -2*ls - lines[i] * yLength/yLevels - 1, xLength, yLength/yLevels);                         // Linea de referencia
    text(toneName(lines[i]), 0, (height -2*ls -1) - yLength/yLevels * lines[i]);                               // Nombre del tono de referencia actual
  }
}

  /**
   * 
   * Interrupción por teclado para la barra espaciadora (caracter " ")
   * Detiene o arranca el procesamiento de datos al presionar la barra espaciadora.
   */
void keyPressed(){
    if(key == 32){
      stop = !stop;
    }
    
}
//*********************************************** DETECCION DE TONO ***************************************************//
/*
* Implementación del algoritmo por parte de TarsosDPS
*-------------------------------------------------------------
*
* TarsosDSP is developed by Joren Six at IPEM, University Ghent
*  
* -------------------------------------------------------------
*
*  Info: http://0110.be/tag/TarsosDSP
*  Github: https://github.com/JorenSix/TarsosDSP
*  Releases: http://0110.be/releases/TarsosDSP/
*  
*  TarsosDSP includes modified source code by various authors,
*  for credits and info, see README.
* 
*/
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
