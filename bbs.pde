#include <EEPROM.h>

/* States */
#define MAIN_MENU 0
#define SENDING_MESSAGE 1
#define READING_LIST 2
#define READING_ITEM 3

/* Display width stuff */
#define MENU_WIDTH 60
#define _print_line() Serial.println("------------------------------------------------------------")
/*************************/

int state = MAIN_MENU; // What state is the user in?

#define MAX_EEPROM_ADDRESS 512
#define FS_DELIM '\0'
#define FS_SPACE '\255'

unsigned int writing_address = 2;

/*
 * Menu stuff 
 */ 
char * main_menu[] = { "Send Message", "Read Messages", "Clear Messages" };

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
  Serial.print("[");
  Serial.print(text[0]);
  Serial.print("]");
  Serial.println( (text + 1) );
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
}

void _print_reading_menu()
{
  _print_line();
  Serial.println("Enter the number of the message you want to read or go [B]ack.");
}

/*****************/

void _print_message(int msg_num)
{
  char v;
  int count = 0;
  for( int i = 2; i < MAX_EEPROM_ADDRESS; i++ )
  {
    v = EEPROM.read(i);
    if( v != FS_DELIM && v != FS_SPACE )
    {
        if( count == 0 )
          count = 1;

        if( count == msg_num )
          Serial.print(v, BYTE);
    }
    else if( v == FS_DELIM )
      count++;

    // stop scanning if we already printed the message.
    if( count > msg_num )
      return;
  }
}

void _print_messages()
{
  char v;
  int len = 0;
  int count = 0;

  for( int i = 2; i < MAX_EEPROM_ADDRESS; i++ )
  {
    v = EEPROM.read(i);
    if( v != FS_DELIM && v != FS_SPACE )
    {
      if( len++ < MENU_WIDTH )
      { 
        if( count == 0 )
          count = 1;

        if( count > 0  && len == 1 )
        {
          Serial.print(count);
          Serial.print("> ");
        }

        Serial.print(v, BYTE);
      }
    }
    else if( v == FS_DELIM )
    {
      len = 0;
      Serial.println("");
      count++;
    }
  }
}

void _clear_messages()
{
  _set_writing_address(2);
  for( int i = 2; i < MAX_EEPROM_ADDRESS; i++ )
    EEPROM.write(i,FS_SPACE);
}

void display_menu() {
  switch (state)
  {
    case MAIN_MENU: 
      _print_menu( main_menu, "Main Menu", 3 );
      break;
    case SENDING_MESSAGE:
      Serial.print("[; to end message]> ");
      break;
    case READING_LIST:
      _print_line();
      _print_messages();
      _print_reading_menu();
      break;
    case READING_ITEM:
      _print_line();
      Serial.println("Go [b]ack or to the [M]ain menu.");
      break;
    default:
      Serial.println("Error: Invalid state in display_menu()");
      state = MAIN_MENU;
  }
}
/* End menu stuff */

//
void handle_input( char * inp )
{
  switch ( state )
  {
    case MAIN_MENU:
      handle_main_menu( inp );
      break;
    case SENDING_MESSAGE:
      handle_sending_message( inp );
      break;
    case READING_LIST:
      handle_reading_list( inp );
      break;
    case READING_ITEM:
      handle_reading_item( inp );
      break;
    default:
      Serial.println("Error: Invalid state in handle_input()");
      state = MAIN_MENU;
  }
}

void handle_main_menu( char * inp )
{
  switch ( *inp )
  {
    case 'S':
    case 's':
      state = SENDING_MESSAGE;
      break;
    case 'R':
    case 'r':
      state = READING_LIST;
      break;
    case 'C':
    case 'c':
      Serial.println("Clearing messages...");
      _clear_messages();
      break;
    default:
      Serial.println("You chose an invalid option.");
  }
}

void handle_reading_list( char * inp )
{
  int item_num;

  switch( *inp )
  {
    case 'B':
    case 'b':
      state = MAIN_MENU;
      break;
    default:
      if( (item_num = atoi(inp)) > 0 )
      {
        _print_line();
        _print_message(item_num);
        Serial.println("");
        state = READING_ITEM;
      }
      else
      {
        Serial.println("You chose an invalid option.");
      }
  }
}

void handle_reading_item( char * inp )
{
  switch (*inp)
  {
    case 'b':
    case 'B':
      state = READING_LIST;
      break;
    case 'm':
    case 'M':
      state = MAIN_MENU;
      break;
    default:
      break;
  }
}
//

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
    EEPROM.write(writing_address++, FS_DELIM);
    _set_writing_address(writing_address); 
    state = MAIN_MENU;
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
