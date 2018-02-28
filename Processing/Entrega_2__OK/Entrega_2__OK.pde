import processing.serial.*; 

// Variables de decodificación

Serial myPort;                 // The serial port
byte[] inBuffer= new byte[5];  // Input Byte from serial port
int buffersize=1;
int i = 0;
int txtSamples = 4681;         // Numero de valores máximo del archivo de texto
long runTime;
boolean dig1;                  // Sensor digital 1
boolean dig2;                  // Sensor digital 2
boolean dig3;                  // Sensor digital 3
boolean dig4;                  // Sensor digital 4
boolean sync = false;          // Indica si la comunicacion serial esta sincronizada
boolean ADC1=false;            // Indica si hay datos por recibir del canal de adquisición 1
boolean ADC2=false;            // Indica si hay datos por recibir del canal de adquisición 2
String[] txtBuffer1 = new String[txtSamples];
String[] txtBuffer2 = new String[txtSamples];

// Variables de ploteo

int ls = 30;
int numScale = 10;
float sampleTime=500; // 213.623 us
float sampleVolt = 0.732421875; // 3000/4096 mV
PFont font;
int xSet=4;
int ySet=3;
int[] xScale={100, 500, 1000, 5000, 10000, 50000, 100000,500000}; // us
int[] yScale={50, 100, 200, 300, 500, 1000, 3000};      // Escala en mV
int xSamples, ySamples;  // Numero de puntos a graficar
float xLabel, yLabel;    // Longitud de los ejes
float xLength, yLength;  // Espacio entre puntos
int OscCount=0;          // Contador de barrido
int preVar=0;
boolean clear=false;   // true cada vez que se llena el osciloscopio o se cambia la escala
boolean stop=false;    // se cambia con ENTER
boolean dataOK=false;
IntList val1Buffer = new IntList();
IntList val2Buffer = new IntList(); 

void setup(){
  printArray(Serial.list()); 
  myPort = new Serial(this, Serial.list()[0], 115200); 
  myPort.buffer(buffersize);
  
  // Ploteo
  size(800,500);
  background(255);
  xLabel = width - 4*ls;
  yLabel = height - 4*ls;
  font = createFont("Arial", ls);
  textFont(font);
  drawGrid();
} 

void draw() { 
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
 
void serialEvent(Serial myPort) { 
  // Lectura del buffer de entrada
  myPort.readBytes(inBuffer);
  if (inBuffer != null) {
    println("BUFFER: ");
    printArray(inBuffer);
  }
  
  // Verifica si en buffer está sincronizado
  syncronize();
  
  if(sync && inBuffer[0] >= 0){  
  // Inicia decodificación del protocolo para la señal del microfono (ADC1)
    if(ADC1){
      val1Buffer.append(decodeADC1());
    }
  // Inicia decodificación del protocolo para la señal del potenciómetro (ADC2)
    if(ADC2){
      val2Buffer.append(decodeADC2());
    }
  // Guardado de las variables en archivos de texto para visualización
  //storeOnTxt("FAKEmuest500");
  }
  
  if(sync){  
    nextHeaderRead();
  }
  
  myPort.buffer(buffersize);
}

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
    dig1=true;
  }
  if(var1==0){
    dig1=false;
  }
  
  // Lectura del sensor digital 2
  var1=inBuffer[0] & 0x20;
  if(var1==32){
    dig2=true;
  }
  if(var1==0){
    dig2=false;
  }
  
  // Lectura del sensor analógico 1
  var1 = (((inBuffer[0] & 0x1F) << 7) + inBuffer[1]);
  ADC1=false;
  return var1;
}

  //
  // Funcion que decodifica los bytes asignados al ADC2 en el protocolo y guarda el valor en val2
int decodeADC2(){
  int var2;
  // Lectura del sensor digital 3
  var2=inBuffer[2] & 0x40;            
  if(var2==64){
    dig3=true;
  }
  if(var2==0){
    dig3=false;
  }
  
  // Lectura del sensor digital 4
  var2=inBuffer[2] & 0x20;
  if(var2==32){
    dig4=true;
  }
  if(var2==0){
    dig4=false;
  }
  
  // Lectura del sensor analógico 1
  var2 = (((inBuffer[2] & 0x1F) << 7) + inBuffer[3]);
  ADC2=false;
  
  return var2;
}

  //
  // Guardado de txtSample muestras en archivos de texto, uno para la señal del microfono y otro para la del potenciómetro
void storeOnTxt(String name){
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
    i=0;
    myPort.stop();
  } 
}

  //
  // Función que asigna el tamaño del buffer, bufferSize, de acuerdo al encabezado del siguiente bloque
void nextHeaderRead(){
  switch(inBuffer[buffersize-1]){
    case -15:
      buffersize=3;
      ADC1=true;
      break;
    case -14:
      buffersize=5;
      ADC1=true;
      ADC2=true;
      break;
    default:
      println("ERROR: CABECERA DESINCRONIZADA");
      sync=false;
      buffersize=1;
      break;
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

void  plot(int var){
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
