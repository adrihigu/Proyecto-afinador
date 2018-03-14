PFont font;
int ls= 24; // Interlineado
int refTone= 48;
int refVolt = 4096;      // Maxima excursion de voltaje que ofrece el potenciometro
FloatList refFrec = new FloatList();
float xLenght;
float yLenght;
float rectWidth;
float rectHeight;
float xLevels = 20;
float yLevels;
String down = "02C5";
String up = "02C4";
IntList pitchBuffer = new IntList();

void setup() {
  initRefFrec();
  
  yLevels = refFrec.size();
  
  size(800,300);
  initDraw();  
}

void draw() {
  // AQUI VA EL CALCULO DEL TONO
  pitchBuffer.append(frec2tone(random(100,1000)));

  background(0);
  drawTunner();
  drawText();
  drawGraph();
  
  if(pitchBuffer.size() > xLevels - 1){
    pitchBuffer.remove(0);
  }
}

void drawTunner(){
  
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
  textSize(rectWidth/2.7);
  for(int i = pitchBuffer.size()-1; i >= 0; i--){
    rectHeight = pitchBuffer.get(i) * yLenght/yLevels;
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
  rect(2*ls, height -2*ls - refTone * yLenght/yLevels - 1, xLenght, yLenght/yLevels);
  
}

void drawText(){
  fill(255);
  text("Tono captado: ",10,ls);
  text(toneName(pitchBuffer.get(pitchBuffer.size()-1)),10+textWidth("Tono captado: "),ls);
  text("Tono de referencia: ",10,2*ls);
  text(toneName(refTone),10+textWidth("Tono de referencia: "),2*ls); // FALTA TONO REFERENCIA
  
  text("Frecuencia asociada: ",10,3*ls);
  text("440 Hz ",10+textWidth("Frecuencia asociada: "),3*ls); // FALTA FRECUENCIA DEL RESULTADO
}

void initRefFrec(){
  int tone = 1;
  int oct = 1;
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
  
  xLenght = width - 4*ls;
  yLenght = height - 6*ls;
  
  rectWidth = xLenght/xLevels;
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
      name = name +"Do#";
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
      println("ERROR: No pitch name: " + tone);
      break;
  }
  return name + oct;
}