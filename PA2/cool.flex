/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

#define YY_SYMBOL_INT(str) \
  cool_yylval.symbol = inttable.add_string(str); \
  return INT_CONST;

#define YY_SYMBOL_TYPEID(str) \
  cool_yylval.symbol = idtable.add_string(str); \
  return TYPEID;

#define YY_SYMBOL_OBJECTID(str) \
  cool_yylval.symbol = idtable.add_string(str); \
  return OBJECTID;

#define YY_SYMBOL_STR(str) \
  if (str) {  \
    cool_yylval.symbol = stringtable.add_string(str); \
    return STR_CONST; \
  } else { \
    cool_yylval.error_msg = "String contains null character"; \
    return ERROR; \
  }

#define YY_BOOL(bool) \
  cool_yylval.boolean = bool; \
  return BOOL_CONST;

#define YY_ERROR(msg) \
  cool_yylval.error_msg = msg; \
  return ERROR;

#define LINE_INC \
  ++curr_lineno;

char* strcheck(char *str)
{
  strcpy(string_buf, str);
  string_buf_ptr = string_buf;
  for (int i = 0; string_buf[i]; i++) {
    if (string_buf[i] == '\\' && string_buf[i + 1])
    {
      switch(string_buf[++i]) {
        case 'b':
          *string_buf_ptr++ = '\b';
          break;
        case 't':
          *string_buf_ptr++ = '\t';
          break;
        case 'n':
          *string_buf_ptr++ = '\n';
          break;
        case 'f':
          *string_buf_ptr++ = '\f';
          break;
        case '0':
          return 0;
      }
    } else {
      *string_buf_ptr++ = string_buf[i];
    }
  }
  *string_buf_ptr = '\0';
  return string_buf + 1;
}

%}

/*
 * Define names for regular expressions here.
 */

ASSIGN          <-
LE              <=
DARROW          =>
WHITE_SPACE     [ \t\f\r\t\v]*
DIGIT           [0-9]
ALPHA           [A-Za-z_]
ALPHA_NUM       ({ALPHA}|{DIGIT})
CAPITAL         [A-Z]
LOWER_CASE      [a-z]
TYPE_ID         {CAPITAL}{ALPHA_NUM}*
OBJECT_ID       {LOWER_CASE}{ALPHA_NUM}*

%Start          COMMENTS
%Start          INLINE_COMMENTS
%Start          STRING

%%

 /*
  *  Nested comments
  */

<INITIAL>\(\*   BEGIN(COMMENTS);
<INITIAL>\-\-   BEGIN(INLINE_COMMENTS);
<INITIAL>\*\)   { YY_ERROR("Unmatched *)"); }

<COMMENTS>[^(\*\)(\n)]+
<COMMENTS>\*\)      BEGIN(INITIAL);
<COMMENTS><<EOF>> { BEGIN(INITIAL); YY_ERROR("EOF in comment"); }

<INLINE_COMMENTS>[^\n]*
<INLINE_COMMENTS>\n { LINE_INC; BEGIN(INITIAL); }

 /*
  *  The multiple-character operators.
  */

<COMMENTS,INITIAL>\n  LINE_INC;

{ASSIGN}    return ASSIGN;
{LE}        return LE;
{DARROW}		return DARROW;

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

class       return CLASS;
else        return ELSE;
fi          return FI;
if          return IF;
in          return IN;
inherits    return INHERITS;
let         return LET;
loop        return LOOP;
pool        return POOL;
then        return THEN;
while       return WHILE;
case        return CASE;
esac        return ESAC;
of          return OF;
new         return NEW;
isvoid      return ISVOID;
not         return NOT;

<INITIAL>"true"   { YY_BOOL(true); }
<INITIAL>"false"  { YY_BOOL(false); }
{DIGIT}           { YY_SYMBOL_INT(yytext); }
{TYPE_ID}         { YY_SYMBOL_TYPEID(yytext); }
{OBJECT_ID}       { YY_SYMBOL_OBJECTID(yytext); }

"+"     return int('+');
"-"     return int('-');
"*"     return int('*');
"/"     return int('/');
"<"     return int('<');
">"     return int('>');
"="     return int('=');
"."     return int('.');
";"     return int(';');
"~"     return int('~');
"{"     return int('{');
"}"     return int('}');
"("     return int('(');
")"     return int(')');
":"     return int(':');
"@"     return int('@');
","     return int(',');
"["     return int('[');
"]"     return int(']');

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

<INITIAL>\"   BEGIN(STRING);

<STRING>[^\n\t\b\f\"]+  yymore();
<STRING>\n  { LINE_INC; YY_ERROR("Unterminated string constant"); }

<STRING>\" {
  BEGIN(INITIAL);
  if (yyleng >= MAX_STR_CONST) {
    YY_ERROR("String constant too long");
  }
  yytext[yyleng - 1] = '\0';
  YY_SYMBOL_STR(strcheck(yytext));
}

<INITIAL>\'\\?.\' {
  yytext[yyleng - 1] = '\0';
  YY_SYMBOL_STR(strcheck(yytext));
}

{WHITE_SPACE}

%%
