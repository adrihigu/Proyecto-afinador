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
int dataSize = 256;                                                      // Cantidad de datos a procesar por el algoritmo YIN
int refSize = int(dataSize/60) + 1;                                          // Cantidad de muestras para referencia del potenciómetro
float sampleRate = 3640.89158153;                                        // Frecuencia de muestreo
float myPitch;                                                           // Resultado de la detección de frecuencia
IntList pitchBuffer = new IntList();                                     // Guarda los tonos detectados

// Variables de interfaz de usuario
PFont font;                                                              // Tipo de letra
int ls = 24;                                                             // Constante para espaciado
int[] refTone = new int[1];                                              // El tono asociado a la medida del potenciómetro
int refVolt = 230;                                                       // Maxima excursion de voltaje que ofrece el potenciometro
int mode;                                                                // Modo de operacion del afinador                 
int holdTone;                                                            // Tono mantenido para el modo HOLD
int[] guitar= {17,22,27,32,36,41};                                       // Tono de las cuerdas de la guitarra (E2, A2, D3, G3, B3, E4)
int[] violin= {20,27,34,17};                                             // Tono de las cuerdas de la guitarra (G2, D3, A3, E2)
FloatList refFrec = new FloatList();                                     // Lista de las frecuencias que se usan para delimitar los tonos musicales
float xLevels = 50;                                                      // Número máximo de rectangulos en la gráfica = Resolución en X
float yLevels;                                                           // Cantidad de tonos = Resolución en Y
float rectWidth;                                                         // Ancho de rectángulos
float rectHeight;                                                        // Alto de rectángulos
String down = "02C5";                                                    // Caracter Unicode. Flecha hacia abajo
String up = "02C4";                                                      // Caracter Unicode. Flecha hacia arriba
boolean stop=false;                                                      // Cuando es true, deja de dibujar
float xLabel, yLabel;                                                    // Longitud de los ejes X e Y
float xLength, yLength;                                                  // Espacio entre puntos del eje X e Y
int ref=100;

void setup(){
  size(800,500);                                                         // Inicializa el tamaño de la ventana
  initRefFrec();                                                         // Inicializa el vector de las frecuencias que se usan para delimitan los tonos musicales 
  yLevels = refFrec.size();                                              // Inicializa el valor de la variable yLevels
  initDraw();                                                            // Inicializa fuentes de texto, carácteres especiales y variables para graficar
}

void draw() {
  
  if(!stop){                                                              // Si no está en pausa...
  val2Buffer.append(ref);
  while(val2Buffer.size() > refSize){
    val2Buffer.remove(0);
  }
      myPitch = random(100,1000);
      val1Buffer.clear();                                                 // Limpia los valores del buffer de audio
      pitchBuffer.append(frec2tone(myPitch));                             // Añade el tono musical asociado a la frecuencia determinada en el buffer de tonos
      //println("DETECTADO: "+ myPitch + ". TONO: " + frec2tone(myPitch));
      background(0);                                                      // Borra el fondo de la interface
      drawPitch();                                                        // Dibuja el grafico de los tonos que se han captado recientemente y la altura de la barra de referencia
      drawRef();                                                          // Dibuja la parte que indica diferencia con respecto al tono deseado
      drawText();                                                         // Dibuja el nombre de los tonos del tono recibido y el de referencia
      if(pitchBuffer.size() > xLevels - 1){                               // Limita el tamaño del buffer de tonos
        pitchBuffer.remove(0);
      }
    //}
  }
}

//*********************************************** INTERFAZ DE USUARIO ***************************************************//
 
  /**
   * 
   * Determina el tono de referencia de acuerdo al modo seleccionado por el usuario.
   * Muestra la parte de la interfaz que indica textualmente si el usuario está por encima o por debajo del tono de referencia.
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
   * Dibuja el grafico de barras verticales asociado a los tonos captados anteriormente.
   * Dibuja la barra horizontal de la referencia y el nombre del tono asociado
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
  fill(255);                    // OJO: queremos rectHeight = pitchBuffer.get(pitchBuffer.size() - 1) * yLength/yLevels;
  text(toneName(pitchBuffer.get(pitchBuffer.size()-1)), width-textWidth(toneName(pitchBuffer.get(pitchBuffer.size()-1))), (height -2*ls -1) - rectHeight);          // Nombre del tono de audio actual
  rect(2*ls, height -2*ls - pitchBuffer.get(pitchBuffer.size()-1) * yLength/yLevels - 1, xLength, yLength/yLevels);                                                   // Linea de tono captado
}

  /**
   * 
   * 
   */
void drawText(){
  fill(255);
  text("Tono captado: ",10,ls);
  text(toneName(pitchBuffer.get(pitchBuffer.size()-1)),10 + textWidth("Tono captado: "),ls);
  
  text("Tono de referencia: ",10,2*ls);
  text(toneName(refTone[0]),10+textWidth("Tono de referencia: "),2*ls); // FALTA TONO REFERENCIA
  
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

void keyPressed(){
    if(key == CODED){
      switch(keyCode){
        case UP:
          ref++;
          break;
        case DOWN:
          ref--;
          break;
      }
    }
    
    if(key == 32){
      stop = !stop;  
}
    preDig = dig1;
    if(key == '1'){
      dig1 = true;  
    }
    else{
      dig1 = false;
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
 
   println("predig = " + preDig + " dig1 = " + dig1);
    preDig = dig2;
    if(key == '2'){
      dig2 = true;  
    }
    else{
      dig2 = false;
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
  
   println("predig = " + preDig + " dig2 = " + dig2);
    preDig = dig3;
    if(key == '3'){
      dig3 = true;  
    }
    else{
      dig3 = false;
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
    
   println("predig = " + preDig + " dig3 = " + dig3);
    preDig = dig4;
    if(key == '4'){
      dig4 = true;  
    }
    else{
      dig4 = false;
    }
   if(preDig == false && dig4 == true){
    stop = !stop;
   }

   println("predig = " + preDig + " dig1 = " + dig1);
   println("modo = " + mode);
   printArray(val2Buffer);
}
