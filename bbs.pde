#include <EEPROM.h>

/* States */
#define MAIN_MENU 0
#define SEND_MENU 1
#define READ_MENU 2
#define SENDING_MESSAGE 3

/* Display width stuff */
#define MENU_WIDTH 60
#define _print_line() Serial.println("************************************************************")
/*************************/

int state = MAIN_MENU; // What state is the user in?

#define MAX_EEPROM_ADDRESS 512

unsigned int writing_address = 2;

/*
 * Menu stuff 
 */ 
char * main_menu[] = { "Send Message", "Read Message" };
char * send_menu[] = { "Enter Message", "Back" };
char * read_menu[] = { "Clear", "Back" };

void _print_space( int len )
{
  for( int i = 0; i < len; i++ )
    Serial.print(" ");
}

void _print_center( int left, const char * text, int right )
{
  _print_space(left);
  Serial.print(text);
  _print_space(right);
  Serial.println("");
}

void _print_item( const char * text, int count )
{ 
  Serial.print(count);
  Serial.print(". ");
  Serial.println(text);
}

void _print_menu( char ** menu, const char * title, int len )
{
  _print_line();
  _print_center( 5, title, 5 );
  _print_line();
  for( int i = 0; i < len; i++ )
  {
    _print_item( menu[i], i+1 );
  }
  _print_line();
}

/*****************/

void _print_messages()
{
  char v;
  int len = 0;
  
  for( int i = 2; i < MAX_EEPROM_ADDRESS; i++ )
  {
    v = EEPROM.read(i);
    if( v != '\0' && v != '\255' )
    {
      if( len++ < MENU_WIDTH )
      {
        Serial.print(v, BYTE);
      }
    }
    else if( v == '\0' )
    {
      len = 0;
      Serial.println("");
    }
  }
}

void _clear_messages()
{
  _set_writing_address(2);
  for( int i = 2; i < MAX_EEPROM_ADDRESS; i++ )
    EEPROM.write(i,'\255');
}

void display_menu() {
  switch (state)
  {
    case SEND_MENU:
      _print_menu( send_menu, "Send A Message", 2 );
      break;
    case READ_MENU:
      _print_menu( read_menu, "Read a Message", 2 );
      _print_messages();
      break;
    case MAIN_MENU: 
      _print_menu( main_menu, "Main Menu", 2 );
      break;
    case SENDING_MESSAGE:
      Serial.print("[; to end message]> ");
      break;
    default:
      Serial.println("Invalid State...");
      state = MAIN_MENU;
  }
}
/* End menu stuff */

//
void handle_input( char * inp )
{
  switch ( state )
  {
    case SEND_MENU:
      handle_send_menu( inp );
      break;
    case READ_MENU:
      handle_read_menu( inp );
      break;
    case MAIN_MENU:
      handle_main_menu( inp );
      break;
    case SENDING_MESSAGE:
      handle_sending_message( inp );
      break;
    default:
      Serial.println("Invalid State...");
      state = MAIN_MENU;
  }
}

void handle_main_menu( char * inp )
{
  switch ( *inp )
  {
    case '1':
      state = SEND_MENU;
      break;
    case '2':
      state = READ_MENU;
      break;
    default:
      Serial.println("You chose an invalid option.");
  }
}

void handle_send_menu( char * inp )
{
  switch ( *inp )
  {
    case '1':
      state = SENDING_MESSAGE;
      break;
    case '2':
      state = MAIN_MENU;
      break;
    default:
      Serial.println("You chose an invalid option.");
  }
}

void handle_read_menu( char * inp )
{
  switch ( *inp )
  {
    case '1':
      _clear_messages();
      break;
    case '2':
      state = MAIN_MENU;
      break;
    default:
      Serial.println("You chose an invalid option.");
  }
}

void _set_writing_address( unsigned int address )
{
  EEPROM.write(0, (address & 255) << 8);
  EEPROM.write(1, address & 255);
  writing_address = address;
}

void _load_writing_address()
{
  // Big Endian, 2 bytes addressing (good for up to 64k EEPROM I guess
  unsigned int _w =  EEPROM.read(1) | ( EEPROM.read(0) << 8 );
  if( _w > 2 )
    writing_address = _w;
}

void handle_sending_message( char * inp )
{
  if( *inp == ';' )
  {
    Serial.println("");
    EEPROM.write(writing_address++, '\0');
    _set_writing_address(writing_address); 
    state = SEND_MENU;
    return;
  }
  Serial.println("");
  Serial.println(inp);
  while( *inp != '\0' && writing_address != MAX_EEPROM_ADDRESS )
  {
    EEPROM.write(writing_address++, *inp++);
  }
}
//

void _read_line(char * buf)
{
  int counter = 0;
  while( Serial.available() )
  {
    *(buf + counter) = Serial.read();
    counter++;
    delay(10);
  }
  *(buf + counter) = '\0';
}

//

void setup()                    
{      
  Serial.begin(9600);
  _load_writing_address();
  display_menu();
}

void loop()                     
{
  char inp[128]; 
  _read_line(inp);
  
  if( inp[0] != '\0' )
  {
    handle_input(inp);
    
    delay(250);
    display_menu();
    inp[0] = '\0';
  }
}
