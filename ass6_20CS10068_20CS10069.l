/*
    * Umang Singla (20CS10068)
    * Utsav Mehta (20CS10069)
*/


/* Declaration of Macros */
%{
    #include <stdio.h>
    #include <stdlib.h>
    #include "ass5_20CS10068_20CS10069_translator.h"
    #include "y.tab.h"
%}

%x COMMENT_SINGLE_LINE
%x COMMENT_MULTI_LINE
%option yylineno
%option noyywrap

DIGIT   [0-9]
ALPHABET [a-zA-Z_]

DIGIT_SEQUENCE {DIGIT}+

IDENTIFIER {ALPHABET}(({ALPHABET}|{DIGIT})*)
INTEGER_CONSTANT ([1-9]{DIGIT}*)|[0]

FRACTIONAL_CONSTANT {DIGIT_SEQUENCE}?\.{DIGIT_SEQUENCE}|{DIGIT_SEQUENCE}\.
EXPONENT_CONSTANT [eE]([+-]?){DIGIT_SEQUENCE}
FLOATING_CONSTANT {FRACTIONAL_CONSTANT}({EXPONENT_CONSTANT}?)|{DIGIT_SEQUENCE}{EXPONENT_CONSTANT}

ENUMERATION_CONSTANT {IDENTIFIER}

ESCAPE_SEQUENCE \\['"?\\abfnrtv]
C_CHAR [^\'\\\n]|{ESCAPE_SEQUENCE}
CHARACTER_CONSTANT              \'({C_CHAR}+)\'

S_CHAR                          [^\"\\\n]|{ESCAPE_SEQUENCE}
S_CHAR_SEQUENCE                 {S_CHAR}+

STRING_LITERAL                  \"({S_CHAR_SEQUENCE})*\"

WS      [ \t]
NEWLINE [\n]                

%%

"auto"                          { return AUTO; }
"break"                         { return BREAK; }
"case"                          { return CASE; }
"char"                          { return _CHAR; }
"const"                         { return CONST; }
"continue"                      { return CONTINUE; }
"default"                       { return DEFAULT; }
"do"                            { return DO; }
"double"                        { return _DOUBLE; }
"else"                          { return ELSE; }
"enum"                          { return ENUM; }             
"extern"                        { return EXTERN; }
"float"                         { return _FLOAT; }
"for"                           { return FOR; }
"goto"                          { return GOTO; }
"if"                            { return IF; }
"inline"                        { return INLINE; }
"int"                           { return _INT; }
"long"                          { return LONG; }
"register"                      { return REGISTER; }
"restrict"                      { return RESTRICT; }
"return"                        { return RETURN; }
"short"                         { return SHORT; }
"signed"                        { return SIGNED; }
"sizeof"                        { return SIZEOF; }
"static"                        { return STATIC; }
"struct"                        { return STRUCT; }
"switch"                        { return SWITCH; }
"typedef"                       { return TYPEDEF; }
"union"                         { return UNION; }
"unsigned"                      { return UNSIGNED; }
"void"                          { return _VOID; }
"volatile"                      { return VOLATILE; }
"while"                         { return WHILE; }
"_Bool"                         { return BOOL; }
"_Complex"                      { return COMPLEX; }
"_Imaginary"                    { return IMAGINARY; }

{IDENTIFIER} {yylval.symbol = currentTable->lookup(yytext); return IDENTIFIER;}
{INTEGER_CONSTANT} {yylval.intVal = atoi(yytext); return INTEGER_CONSTANT;}

{FLOATING_CONSTANT} {yylval.fVal = strdup(yytext); return FLOATING_CONSTANT;}
{CHARACTER_CONSTANT} {yylval.charVal = strdup(yytext); return CHARACTER_CONSTANT;}
{STRING_LITERAL} {yylval.strVal = strdup(yytext); return STRING_LITERAL;}
{WS} {}

"/*"     {BEGIN(COMMENT_MULTI_LINE);}
<COMMENT_MULTI_LINE>. {}
<COMMENT_MULTI_LINE>\n {}
<COMMENT_MULTI_LINE>"*/" {BEGIN(INITIAL);}

"//" {BEGIN(COMMENT_SINGLE_LINE);}
<COMMENT_SINGLE_LINE>.          {}
<COMMENT_SINGLE_LINE>\n         { BEGIN(INITIAL);}
<COMMENT_SINGLE_LINE><<EOF>>    { BEGIN(INITIAL);}

"["                             { return LEFT_SQUARE_BRACE; }
"]"                             { return RIGHT_SQUARE_BRACE; }
"("                             { return LEFT_PARENTHESIS; }
")"                             { return RIGHT_PARENTHESIS; }
"{"                             { return LEFT_CURLY_BRACE; }
"}"                             { return RIGHT_CURLY_BRACE; }
"."                             { return DOT; }
"->"                            { return ARROW; }
"++"                            { return INCREMENT; }
"--"                            { return DECREMENT; }
"&"                             { return BITWISE_AND; }
"*"                             { return MULTIPLY; }
"+"                             { return ADD; }
"-"                             { return SUBTRACT; }
"~"                             { return BITWISE_NOR; }
"!"                             { return NOT; }
"/"                             { return DIVIDE; }
"%"                             { return MODULUS; }
"<<"                            { return LEFT_SHIFT; }
">>"                            { return RIGHT_SHIFT; }
"<"                             { return LESS_THAN; }
">"                             { return GREATER_THAN; }
"<="                            { return LESS_THAN_EQUAL; }
">="                            { return GREATER_THAN_EQUAL; }
"=="                            { return EQUAL; }
"!="                            { return NOT_EQUAL; }
"^"                             { return BITWISE_XOR; }
"|"                             { return BITWISE_OR; }
"&&"                            { return LOGICAL_AND; }
"||"                            { return LOGICAL_OR; }
"?"                             { return QUESTION_MARK; }
":"                             { return COLON; }
";"                             { return SEMICOLON; }
"..."                           { return ELLIPSIS; }
"="                             { return ASSIGN; }
"*="                            { return MULTIPLY_ASSIGN; }
"/="                            { return DIVIDE_ASSIGN; }
"%="                            { return MODULUS_ASSIGN; }
"+="                            { return ADD_ASSIGN; }
"-="                            { return SUBTRACT_ASSIGN; }
"<<="                           { return LEFT_SHIFT_ASSIGN; }
">>="                           { return RIGHT_SHIFT_ASSIGN; }
"&="                            { return AND_ASSIGN; }
"^="                            { return XOR_ASSIGN; }
"|="                            { return OR_ASSIGN; }
","                             { return COMMA; }
"#"                             { return HASH; }

{NEWLINE} {}
.                               {printf("Error <%s> at line %d.", yytext, yylineno); return ERROR;}
%%