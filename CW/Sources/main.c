/* ###################################################################
**     Filename    : ProcessorExpert.c
**     Project     : ProcessorExpert
**     Processor   : MC9S08QE128CLK
**     Version     : Driver 01.12
**     Compiler    : CodeWarrior HCS08 C Compiler
**     Date/Time   : 2014-02-18, 15:36, # CodeGen: 0
**     Abstract    :
**         Main module.
**         This module contains user's application code.
**     Settings    :
**     Contents    :
**         No public methods
**
** ###################################################################*/
/*!
** @file ProcessorExpert.c
** @version 01.12
** @brief
**         Main module.
**         This module contains user's application code.
*/         
/*!
**  @addtogroup ProcessorExpert_module ProcessorExpert module documentation
**  @{
*/         
/* MODULE ProcessorExpert */


/* Including needed modules to compile this module/procedure */
#include "Cpu.h"
#include "Events.h"
#include "Bit1.h"
#include "TI1.h"
#include "AS1.h"
#include "AD1.h"
#include "Cap1.h"
#include "Bit2.h"
#include "Bit3.h"
#include "Bit4.h"
/* Include shared modules, which are used for whole project */
#include "PE_Types.h"
#include "PE_Error.h"
#include "PE_Const.h"
#include "IO_Map.h"

/* User includes (#include below this line is not maintained by Processor Expert) */

unsigned char estado1 = ESPERAR;
unsigned char estado2 = ESPERAR;
unsigned char CodError;
unsigned char ctrama[5];		// Bytes enviado por puerto serial
unsigned char dig1;
unsigned char dig2;
unsigned int Enviados = 2;		// Esta variable no aporta nada más sino el número de elementos del arreglo a enviar.
unsigned int signals=1; 		// Numero de medidas analogicas para el envio
unsigned int count=0;
unsigned int ADC1;
unsigned int ADC2;

void main(void)
{
  /* Write your local variable definition here */
	
  /*** Processor Expert internal initialization. DON'T REMOVE THIS CODE!!! ***/
  PE_low_level_init();
  /*** End of Processor Expert internal initialization.                    ***/

  /* Write your code here */
    
  /* For example: for(;;) { } */

  for(;;){

  	switch (estado1){
  		case ESPERAR:
  			break;
  			
  		case MEDIR:
  			CodError = AD1_Measure(TRUE);
  			CodError = AD1_GetChanValue(0,&ADC1);
  			estado1 = ENVIAR;
  			signals = 3;
  			if(count>=78){
  	  			CodError = AD1_Measure(TRUE);
  	  			CodError = AD1_GetChanValue(1,&ADC2);
  				estado2=ENVIAR;
  				count=0;
  			}
  			break;
  			
  		case ENVIAR:
  			ctrama[0]= 0xF1 + estado2;                      					// Header
  			ctrama[1]= ((ADC1 >> 11) & 0x1F) + (((_PTDD.Byte) & 0x0CU) << 3);	// Primer byte, ADC1
  			ctrama[2]= (ADC1 >> 4) & 0x7F;                  					// Second byte, ADC1
  			estado1 = ESPERAR;
  			
  			if(estado2==ENVIAR){
  				ctrama[3]= ((ADC2 >> 11) & 0x1F) + (((_PTAD.Byte) & 0x0CU) << 3);	// Third byte, ADC2
  				ctrama[4]= (ADC2 >> 4) & 0x7F;              					 	// Forth byte, ADC2
  	  			signals = 5;
  				estado2 = ESPERAR;
  			}
  			
  			CodError = AS1_SendBlock(ctrama,signals,&Enviados);
  			break;
  			
  		default:
  			break;
  	}
  }
  
  /*** Don't write any code pass this line, or it will be deleted during code generation. ***/
  /*** Processor Expert end of main routine. DON'T MODIFY THIS CODE!!! ***/
  for(;;){}
  /*** Processor Expert end of main routine. DON'T WRITE CODE BELOW!!! ***/
} /*** End of main routine. DO NOT MODIFY THIS TEXT!!! ***/

/* END ProcessorExpert */
/*!
** @}
*/
/*
** ###################################################################
**
**     This file was created by Processor Expert 10.3 [05.08]
**     for the Freescale HCS08 series of microcontrollers.
**
** ###################################################################
*/
