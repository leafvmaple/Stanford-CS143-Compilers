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

int comments_num = 0;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

#define YY_ERROR(msg) \
  cool_yylval.error_msg = msg; \
  return ERROR;

#define YY_SYMBOL_INT(str) \
  cool_yylval.symbol = inttable.add_string(str); \
  return INT_CONST;

#define YY_SYMBOL_TYPEID(str) \
  cool_yylval.symbol = idtable.add_string(str); \
  return TYPEID;

#define YY_SYMBOL_OBJECTID(str) \
  cool_yylval.symbol = idtable.add_string(str); \
  return OBJECTID;

#define YY_SYMBOL_STR(err) \
  if (!err) {  \
    cool_yylval.symbol = stringtable.add_string(string_buf); \
    return STR_CONST; \
  } else if (err == 1) { \
    YY_ERROR("String contains escaped null character.");  \
  } else if (err == 2) { \
    YY_ERROR("String constant too long");  \
  }

#define YY_BOOL(bool) \
  cool_yylval.boolean = bool; \
  return BOOL_CONST;

#define LINE_INC \
  ++curr_lineno;

int strcheck(char *str, int strlen)
{
  string_buf_ptr = string_buf;
  for (int i = 0; i < strlen - 1; i++) {
    if (!str[i])
      return 1;
    if (str[i] == '\\' && str[i + 1])
    {
      switch(str[++i]) {
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
        default:
          *string_buf_ptr++ = str[i];
      }
    } else {
      *string_buf_ptr++ = str[i];
    }
    if (string_buf_ptr - string_buf >= MAX_STR_CONST) {
      return 2;
    }
  }
  *string_buf_ptr = '\0';
  return 0;
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

<INITIAL,COMMENTS>"(*"   { ++comments_num; BEGIN(COMMENTS); }
<INITIAL>"--"              BEGIN(INLINE_COMMENTS);
<INITIAL>"*)"            { YY_ERROR("Unmatched *)"); }

<COMMENTS>[^\n()*]+

<COMMENTS>"*)" {
  --comments_num;
  if (comments_num <= 0) {
    BEGIN(INITIAL);
  }
}

<COMMENTS>[*()]
<COMMENTS><<EOF>> {
  comments_num = 0;
  BEGIN(INITIAL);
  YY_ERROR("EOF in comment");
}

<INLINE_COMMENTS>[^\n]*
<INLINE_COMMENTS>\n { LINE_INC; BEGIN(INITIAL); }

 /*
  *  The multiple-character operators.
  */

<COMMENTS,INITIAL>\n  LINE_INC;

{ASSIGN}    return ASSIGN;
{LE}        return LE;
{DARROW}    return DARROW;

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

(?i:class)       return CLASS;
(?i:else)        return ELSE;
(?i:fi)          return FI;
(?i:if)          return IF;
(?i:in)          return IN;
(?i:inherits)    return INHERITS;
(?i:let)         return LET;
(?i:loop)        return LOOP;
(?i:pool)        return POOL;
(?i:then)        return THEN;
(?i:while)       return WHILE;
(?i:case)        return CASE;
(?i:esac)        return ESAC;
(?i:of)          return OF;
(?i:new)         return NEW;
(?i:isvoid)      return ISVOID;
(?i:not)         return NOT;

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

<INITIAL>\"         BEGIN(STRING);

<STRING>[^\n\"\\]+  yymore();
<STRING>\\[^\n]     yymore();
<STRING>\\\n      { LINE_INC; yymore(); }

<STRING>\n {
  LINE_INC;
  BEGIN(INITIAL);
  YY_ERROR("Unterminated string constant");
}

<STRING>\" {
  BEGIN(INITIAL);
  YY_SYMBOL_STR(strcheck(yytext, yyleng));
}

<STRING><<EOF>> {
  BEGIN(INITIAL);
  yyrestart(yyin);
  YY_ERROR("EOF in string constant");
}

<INITIAL>\'\\?.\' {;
  YY_SYMBOL_STR(strcheck(yytext, yyleng));
}

t(?i:rue)       { YY_BOOL(true); }
f(?i:alse)      { YY_BOOL(false); }
{DIGIT}*        { YY_SYMBOL_INT(yytext); }
{TYPE_ID}       { YY_SYMBOL_TYPEID(yytext); }
{OBJECT_ID}     { YY_SYMBOL_OBJECTID(yytext); }

"+"     return int('+');
"-"     return int('-');
"*"     return int('*');
"/"     return int('/');
"<"     return int('<');
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

{WHITE_SPACE}

.       { YY_ERROR(yytext); }

%%
