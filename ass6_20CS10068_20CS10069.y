%{
    #include "ass5_20CS10068_20CS10069_translator.h"
    extern int yylex();
    extern int yylineno;
    void yyerror(string);
%}

/*
    intVal, fVal, charVal, strVal for storing constants entered by user in code
    idetifierVal for storing name of identifier
    unaryOp for storing the unary operator encountered
    instrCnt for backpatching
    paramCnt for storing number of parameters passed to function
    symbolType to store most recent type encountered
    expression, statement and array types and symbols with their usual meanings as discussed in class
*/

%union {
    int intVal;
    char *fVal;
    char *charVal;
    char *strVal;
    char *idVal;
    int instrCnt;
    Expression *expression;
    Statement *statement;
    Array *array;
    SymbolType *symbolType;
    Symbol *symbol;
    char *unaryOp;
    int paramCnt;
}

%token AUTO
%token BREAK
%token CASE
%token _CHAR
%token CONST
%token CONTINUE
%token DEFAULT
%token DO
%token _DOUBLE
%token ELSE
%token ENUM
%token EXTERN
%token _FLOAT
%token FOR
%token GOTO
%token IF
%token INLINE
%token _INT
%token LONG
%token REGISTER
%token RESTRICT
%token RETURN
%token SHORT
%token SIGNED
%token SIZEOF
%token STATIC
%token STRUCT
%token SWITCH
%token TYPEDEF
%token UNION
%token UNSIGNED
%token _VOID
%token VOLATILE
%token WHILE
%token BOOL
%token COMPLEX
%token IMAGINARY

/*
IDENTIFIER points to its entry in the symbol table
The remaining are constants from the code
*/

%token<symbol> IDENTIFIER
%token<intVal> INTEGER_CONSTANT
%token<fVal> FLOATING_CONSTANT
%token<charVal> CHARACTER_CONSTANT
%token<strVal> STRING_LITERAL

%token LEFT_SQUARE_BRACE
%token RIGHT_SQUARE_BRACE
%token LEFT_PARENTHESIS
%token RIGHT_PARENTHESIS
%token LEFT_CURLY_BRACE
%token RIGHT_CURLY_BRACE
%token DOT
%token ARROW
%token INCREMENT
%token DECREMENT
%token BITWISE_AND
%token MULTIPLY
%token ADD
%token SUBTRACT
%token BITWISE_NOR
%token NOT
%token DIVIDE
%token MODULUS
%token LEFT_SHIFT
%token RIGHT_SHIFT
%token LESS_THAN
%token GREATER_THAN
%token LESS_THAN_EQUAL
%token GREATER_THAN_EQUAL
%token EQUAL
%token NOT_EQUAL
%token BITWISE_XOR
%token BITWISE_OR
%token LOGICAL_AND
%token LOGICAL_OR
%token QUESTION_MARK
%token COLON
%token SEMICOLON
%token ELLIPSIS
%token ASSIGN
%token MULTIPLY_ASSIGN
%token DIVIDE_ASSIGN
%token MODULUS_ASSIGN
%token ADD_ASSIGN
%token SUBTRACT_ASSIGN
%token LEFT_SHIFT_ASSIGN
%token RIGHT_SHIFT_ASSIGN
%token AND_ASSIGN
%token OR_ASSIGN
%token XOR_ASSIGN
%token COMMA
%token HASH
%token ERROR

%right THEN ELSE

// Declaring the non-terminal expressions of type-expression
%type<expression>
	expression
	primary_expression 
	multiplicative_expression
	additive_expression
	shift_expression
	relational_expression
	equality_expression
	AND_expression
	exclusive_OR_expression
	inclusive_OR_expression
	logical_AND_expression
	logical_OR_expression
	conditional_expression
	assignment_expression
	expression_statement
    expression_opt

// Statements
%type <statement>  
    statement
	compound_statement
	selection_statement
	iteration_statement
	labeled_statement 
	jump_statement
	block_item
	block_item_list
	block_item_list_opt
    N

// Arrays
%type<array> 
    postfix_expression
	unary_expression
	cast_expression

// symbol type
%type<symbolType> 
    pointer

// Symbol
%type<symbol> 
    initialiser
    direct_declarator 
    init_declarator 
    declarator

// Instruction dummy non-terminal used for backpatching
%type <instrCnt> 
    M

// Store unary operators as character
%type<unaryOp> 
    unary_operator

// Store number of parameters passed to function as integer variable
%type<paramCnt> 
    argument_expression_list 
    argument_expression_list_opt

%start translation_unit

%%

/*
Expressions  - 
    - For constants, assign the initial value to a fresh temporary, point the new expression symbol to this temporary
    - For identifiers, assign the identifier value directly
*/

primary_expression: 
                    IDENTIFIER 
                        { 
                            $$ = new Expression(); // create new non boolean expression and symbol is the identifier
                            $$->type = Expression::NONBOOLEAN, $$->symbol = $1;
                        }
                    | INTEGER_CONSTANT 
                        { 
                            $$ = new Expression();
                            $$->symbol = gentemp(SymbolType::INT, toString($1)), emit("=", $$->symbol->name, $1);
                        }
                    | FLOATING_CONSTANT 
                        {
                            $$ = new Expression();
                            $$->symbol = gentemp(SymbolType::FLOAT, $1), emit("=", $$->symbol->name, $1);
                        }
                    | CHARACTER_CONSTANT 
                        { 
                            $$ = new Expression();
                            $$->symbol = gentemp(SymbolType::CHAR, $1), emit("=", $$->symbol->name, $1);
                        }
                    | STRING_LITERAL 
                        { 
                            $$ = new Expression();
		                    $$->symbol = gentemp(SymbolType::POINTER, $1), $$->symbol->type->arrayType = new SymbolType(SymbolType::CHAR);
                        }
                    | LEFT_PARENTHESIS expression RIGHT_PARENTHESIS
                        { 
                            $$ = $2;
                        }
                    ;

postfix_expression:
                    primary_expression
                        { 
                            // Maintain the symbol from primary expression and create a new array
                            $$ = new Array();
                            $$->symbol = $1->symbol, $$->temp = $$->symbol, $$->subArrayType = $1->symbol->type;
                        }
                    | postfix_expression LEFT_SQUARE_BRACE expression RIGHT_SQUARE_BRACE
                        { 
                            // Create a new array
                            $$ = new Array();
                            $$->symbol = $1->symbol;    // use the previous symbol
                            $$->subArrayType = $1->subArrayType->arrayType; // use the previous sub array type
                            $$->temp = gentemp(SymbolType::INT); // temporary to compute location
                            $$->type = Array::ARRAY;    // type - array

                            if($1->type == Array::ARRAY) {
                                // multiply the size of previous array with this size and add
                                Symbol *sym = gentemp(SymbolType::INT);
                                emit("*", sym->name, $3->symbol->name, toString($$->subArrayType->getSize()));
                                emit("+", $$->temp->name, $1->temp->name, sym->name);
                            } else
                                emit("*", $$->temp->name, $3->symbol->name, toString($$->subArrayType->getSize()));
                        }
                    | postfix_expression LEFT_PARENTHESIS argument_expression_list_opt RIGHT_PARENTHESIS
                        { 
                            // For a function call, store the parameter-count 
                            $$ = new Array();
                            $$->symbol = gentemp($1->symbol->type->type), emit("call", $$->symbol->name, $1->symbol->name, toString($3));
                        }
                    | postfix_expression DOT IDENTIFIER
                        { 
                        }
                    | postfix_expression ARROW IDENTIFIER
                        { 
                        }
                    | postfix_expression INCREMENT
                        { 
                            // For post increment operation, generate temporary, assign previous value, then add one
                            $$ = new Array();
                            $$->symbol = gentemp($1->symbol->type->type);
                            emit("=", $$->symbol->name, $1->symbol->name);
                            emit("+", $1->symbol->name, $1->symbol->name, toString(1)); 
                        }
                    | postfix_expression DECREMENT
                        { 
                            // For post decrement operation, generate temporary, assign previous value, then subtract one
                            $$ = new Array();
                            $$->symbol = gentemp($1->symbol->type->type);
                            emit("=", $$->symbol->name, $1->symbol->name);
                            emit("-", $1->symbol->name, $1->symbol->name, toString(1));
                        }
                    | LEFT_PARENTHESIS type_name RIGHT_PARENTHESIS LEFT_CURLY_BRACE initialiser_list RIGHT_CURLY_BRACE
                        { 
                        }
                    | LEFT_PARENTHESIS type_name RIGHT_PARENTHESIS LEFT_CURLY_BRACE initialiser_list COMMA RIGHT_CURLY_BRACE
                        { 
                        }
                    ;

argument_expression_list_opt:
                                argument_expression_list
                                    { 
                                        $$ = $1;
                                    }
                                | 
                                    { 
                                        $$ = 0;     // 0 => no parameters
                                    }
                                ;

argument_expression_list:
                            assignment_expression
                                { 
                                    // For first param, set parameter-count = 1
                                    emit("param", $1->symbol->name), $$ = 1;
                                }
                            | argument_expression_list COMMA assignment_expression
                                { 
                                    // For new param, parameter-count = previous parameter-count + 1
                                    emit("param", $3->symbol->name), $$ = $1 + 1; 
                                }
                            ;

unary_expression:
                    postfix_expression
                        { 
                            $$ = $1;
                        }
                    | INCREMENT unary_expression
                        { 
                            // For pre increment operator, add 1 to the same variable
                            $$ = $2, emit("+", $2->symbol->name, $2->symbol->name, toString(1));
                        }
                    | DECREMENT unary_expression
                        { 
                            // For pre decrement operator, subtract 1 from the same variable
                            $$ = $2, emit("-", $2->symbol->name, $2->symbol->name, toString(1));
                        }
                    | unary_operator cast_expression
                        { 
                            if(strcmp($1, "&") == 0) {
                                $$ = new Array();
                                $$->symbol = gentemp(SymbolType::POINTER);
                                $$->symbol->type->arrayType = $2->symbol->type;
                                emit("=&", $$->symbol->name, $2->symbol->name);
                            } else if(strcmp($1, "*") == 0) {
                                $$ = new Array();
                                $$->symbol = $2->symbol;
                                $$->temp = gentemp($2->temp->type->arrayType->type);
                                $$->temp->type->arrayType = $2->temp->type->arrayType->arrayType;
                                $$->type = Array::POINTER;
                                emit("=*", $$->temp->name, $2->temp->name);
                            } else if(strcmp($1, "+") == 0) {
                                $$ = $2;
                            } else {
                                $$ = new Array();
                                $$->symbol = gentemp($2->symbol->type->type);
                                emit($1, $$->symbol->name, $2->symbol->name);
                            }
                        }
                    | SIZEOF unary_expression
                        { 
                        }
                    | SIZEOF LEFT_PARENTHESIS type_name RIGHT_PARENTHESIS
                        { 
                        }
                    ;

/*
For the unary operators - 
*/

unary_operator:
                BITWISE_AND
                    {  
                        $$ = strdup("&"); 
                    }
                | MULTIPLY
                    { 
                        $$ = strdup("*"); 
                    }
                | ADD
                    { 
                        $$ = strdup("+"); 
                    }
                | SUBTRACT
                    { 
                        $$ = strdup("=-"); 
                    }
                | BITWISE_NOR
                    { 
                        $$ = strdup("~"); 
                    }
                | NOT
                    { 
                        $$ = strdup("!"); 
                    }
                ;

cast_expression:
                unary_expression
                    { 
                        $$ = $1;
                    }
                | LEFT_PARENTHESIS type_name RIGHT_PARENTHESIS cast_expression
                    { 
                        $$ = new Array();
                        $$->symbol = $4->symbol->convert(currentType);
                    }
                ;

/*
Mapping an array => expression
Determine the type of array
Assign, to the newly generated temporary, the location of previous temporary

Apply multiplication, division or modulo operation
Take care of type checking

Repeat the same for additive expressions and shift expressions
*/

multiplicative_expression:
                            cast_expression
                                { 
                                    SymbolType *baseType = $1->symbol->type;
                                    while(baseType->arrayType)
                                        baseType = baseType->arrayType;
                                    $$ = new Expression();
                                    if($1->type == Array::ARRAY) {
                                        $$->symbol = gentemp(baseType->type);
                                        emit("=[]", $$->symbol->name, $1->symbol->name, $1->temp->name);
                                    } else if($1->type == Array::POINTER) {
                                        $$->symbol = $1->temp;
                                    } else {
                                        $$->symbol = $1->symbol;
                                    }
                                }
                            | multiplicative_expression MULTIPLY cast_expression
                                { 
                                    SymbolType *baseType = $3->symbol->type;
                                    while(baseType->arrayType)
                                        baseType = baseType->arrayType;
                                    Symbol *temp;
                                    if($3->type == Array::ARRAY) {
                                        temp = gentemp(baseType->type);
                                        emit("=[]", temp->name, $3->symbol->name, $3->temp->name);
                                    } else if($3->type == Array::POINTER)
                                        temp = $3->temp;
                                    else
                                        temp = $3->symbol;
                                    
                                    if(typeCheck($1->symbol, temp)) {
                                        $$ = new Expression();
                                        $$->symbol = gentemp($1->symbol->type->type), emit("*", $$->symbol->name, $1->symbol->name, temp->name);
                                    } else
                                        yyerror("Type error.");
                                }
                            | multiplicative_expression DIVIDE cast_expression
                                { 
                                    SymbolType *baseType = $3->symbol->type;
                                    while(baseType->arrayType)
                                        baseType = baseType->arrayType;
                                    Symbol *temp;
                                    if($3->type == Array::ARRAY) {
                                        temp = gentemp(baseType->type);
                                        emit("=[]", temp->name, $3->symbol->name, $3->temp->name);
                                    } else if($3->type == Array::POINTER) {
                                        temp = $3->temp;
                                    } else {
                                        temp = $3->symbol;
                                    }
                                    if(typeCheck($1->symbol, temp)) {
                                        $$ = new Expression();
                                        $$->symbol = gentemp($1->symbol->type->type);
                                        emit("/", $$->symbol->name, $1->symbol->name, temp->name);
                                    } else {
                                        yyerror("Type error.");
                                    }
                                }
                            | multiplicative_expression MODULUS cast_expression
                                { 
                                    SymbolType *baseType = $3->symbol->type;
                                    while(baseType->arrayType)
                                        baseType = baseType->arrayType;
                                    Symbol *temp;
                                    if($3->type == Array::ARRAY) {
                                        temp = gentemp(baseType->type);
                                        emit("=[]", temp->name, $3->symbol->name, $3->temp->name);
                                    } else if($3->type == Array::POINTER) {
                                        temp = $3->temp;
                                    } else {
                                        temp = $3->symbol;
                                    }
                                    if(typeCheck($1->symbol, temp)) {
                                        $$ = new Expression();
                                        $$->symbol = gentemp($1->symbol->type->type);
                                        emit("%", $$->symbol->name, $1->symbol->name, temp->name);
                                    } else {
                                        yyerror("Type error.");
                                    }
                                }
                            ;

additive_expression:
                    multiplicative_expression
                        { 
                            $$ = $1;
                        }
                    | additive_expression ADD multiplicative_expression
                        { 
                            if(typeCheck($1->symbol, $3->symbol)) {
                                $$ = new Expression();
                                $$->symbol = gentemp($1->symbol->type->type);
                                emit("+", $$->symbol->name, $1->symbol->name, $3->symbol->name);
                            } else {
                                yyerror("Type error.");
                            }
                        }
                    | additive_expression SUBTRACT multiplicative_expression
                        { 
                            if(typeCheck($1->symbol, $3->symbol)) {
                                $$ = new Expression();
                                $$->symbol = gentemp($1->symbol->type->type);
                                emit("-", $$->symbol->name, $1->symbol->name, $3->symbol->name);
                            } else {
                                yyerror("Type error.");
                            }
                        }
                    ;

shift_expression:
                    additive_expression
                        { 
                            $$ = $1;
                        }
                    | shift_expression LEFT_SHIFT additive_expression
                        { 
                            if($3->symbol->type->type == SymbolType::INT) {
                                $$ = new Expression();
                                $$->symbol = gentemp(SymbolType::INT);
                                emit("<<", $$->symbol->name, $1->symbol->name, $3->symbol->name);
                            } else {
                                yyerror("Type error.");
                            }
                        }
                    | shift_expression RIGHT_SHIFT additive_expression
                        { 
                            if($3->symbol->type->type == SymbolType::INT) {
                                $$ = new Expression();
                                $$->symbol = gentemp(SymbolType::INT);
                                emit(">>", $$->symbol->name, $1->symbol->name, $3->symbol->name);
                            } else {
                                yyerror("Type error.");
                            }
                        }
                    ;

/*
Boolean expressions are derived for the following translations
trueList and falseList are created which will be used for backpatching
*/

relational_expression:
                        shift_expression
                            { 
                                $$ = $1;
                            }
                        | relational_expression LESS_THAN shift_expression
                            { 
                                if(typeCheck($1->symbol, $3->symbol)) {
                                    $$ = new Expression();
                                    $$->type = Expression::BOOLEAN;
                                    $$->trueList = makeList(nextInstruction());
			                        $$->falseList = makeList(nextInstruction() + 1);
                                    emit("<", "", $1->symbol->name, $3->symbol->name);
                                    emit("goto", "");
                                } else
                                    yyerror("Type error.");
                            }
                        | relational_expression GREATER_THAN shift_expression
                            { 
                                if(typeCheck($1->symbol, $3->symbol)) {
                                    $$ = new Expression();
                                    $$->type = Expression::BOOLEAN;
                                    $$->trueList = makeList(nextInstruction());
			                        $$->falseList = makeList(nextInstruction() + 1);
                                    emit(">", "", $1->symbol->name, $3->symbol->name);
                                    emit("goto", "");
                                } else
                                    yyerror("Type error.");
                            }
                        | relational_expression LESS_THAN_EQUAL shift_expression
                            { 
                                if(typeCheck($1->symbol, $3->symbol)) {
                                    $$ = new Expression();
                                    $$->type = Expression::BOOLEAN;
                                    $$->trueList = makeList(nextInstruction());
			                        $$->falseList = makeList(nextInstruction() + 1);
                                    emit("<=", "", $1->symbol->name, $3->symbol->name);
                                    emit("goto", "");
                                } else
                                    yyerror("Type error.");
                            }
                        | relational_expression GREATER_THAN_EQUAL shift_expression
                            { 
                                if(typeCheck($1->symbol, $3->symbol)) {
                                    $$ = new Expression();
                                    $$->type = Expression::BOOLEAN;
                                    $$->trueList = makeList(nextInstruction());
			                        $$->falseList = makeList(nextInstruction() + 1);
                                    emit(">=", "", $1->symbol->name, $3->symbol->name);
                                    emit("goto", "");
                                } else 
                                    yyerror("Type error.");
                            }
                        ;

equality_expression:
                    relational_expression
                        { 
                            $$ = $1;
                        }
                    | equality_expression EQUAL relational_expression
                        { 
                            if(typeCheck($1->symbol, $3->symbol)) {
                                $1->toInt();
                                $3->toInt();
                                $$ = new Expression();
                                $$->type = Expression::BOOLEAN;
                                $$->trueList = makeList(nextInstruction());
			                    $$->falseList = makeList(nextInstruction() + 1);
                                emit("==", "", $1->symbol->name, $3->symbol->name);
                                emit("goto", "");
                            } else
                                yyerror("Type error.");
                        }
                    | equality_expression NOT_EQUAL relational_expression
                        { 
                            if(typeCheck($1->symbol, $3->symbol)) {
                                $1->toInt();
                                $3->toInt();
                                $$ = new Expression();
                                $$->type = Expression::BOOLEAN;
                                $$->trueList = makeList(nextInstruction());
			                    $$->falseList = makeList(nextInstruction() + 1);
                                emit("!=", "", $1->symbol->name, $3->symbol->name);
                                emit("goto", "");
                            } else
                                yyerror("Type error.");
                        }
                    ;

/*
Integer expressions are derived for the following translations
Result is stored in a temporary variable
*/

AND_expression:
                equality_expression
                    { 
                        $$ = $1;
                    }
                | AND_expression BITWISE_AND equality_expression
                    { 
                        $1->toInt(), $3->toInt();
                        $$ = new Expression();
                        $$->type = Expression::NONBOOLEAN, $$->symbol = gentemp(SymbolType::INT);
                        emit("&", $$->symbol->name, $1->symbol->name, $3->symbol->name);
                    }
                ;

exclusive_OR_expression:
                        AND_expression
                            { 
                                $$ = $1;
                            }
                        | exclusive_OR_expression BITWISE_XOR AND_expression
                            { 
                                $1->toInt(), $3->toInt();
                                $$ = new Expression();
                                $$->type = Expression::NONBOOLEAN, $$->symbol = gentemp(SymbolType::INT);
                                emit("^", $$->symbol->name, $1->symbol->name, $3->symbol->name);
                            }
                        ;

inclusive_OR_expression:
                        exclusive_OR_expression
                            { 
                                $$ = $1;
                            }
                        | inclusive_OR_expression BITWISE_OR exclusive_OR_expression
                            { 
                                $1->toInt(), $3->toInt();
                                $$ = new Expression();
                                $$->type = Expression::NONBOOLEAN, $$->symbol = gentemp(SymbolType::INT);
                                emit("|", $$->symbol->name, $1->symbol->name, $3->symbol->name);
                            }
                        ;

/*
M = Marker rule, used for backpatching, stores the next instruction
N = Fall through guard rule, holds the indices with exits at N exits at N
*/

M:  
        {
            $$ = nextInstruction();
        }   
    ;

N: 
        {
            $$ = new Statement();
            $$->nextList = makeList(nextInstruction());
            emit("goto", "");
        }
	;

/*

The backpatching and merge being done for the next three translations is as discussed in the class
A conversion into BOOL is made and appropriate backpatching is carried out

For logical and
backpatch(B 1 .truelist, M.instr );
B.truelist = B 2 .truelist;
B.falselist = merge(B 1 .falselist, B 2 .falselist);

For logical or
backpatch(B 1 .falselist, M.instr );
B.truelist = merge(B 1 .truelist, B 2 .truelist);
B.falselist = B 2 .falselist;

For ? :
E .loc = gentemp();
E .type = E 2 .type; // Assume E 2 .type = E 3 .type
emit(E .loc ’=’ E 3 .loc); // Control gets here by fall-through
l = makelist(nextinstr );
emit(goto .... );
backpatch(N 2 .nextlist, nextinstr );
emit(E .loc ’=’ E 2 .loc);
l = merge(l, makelist(nextinstr ));
emit(goto .... );
backpatch(N 1 .nextlist, nextinstr );
convInt2Bool(E 1 );
backpatch(E 1 .truelist, M 1 .instr );
backpatch(E 1 .falselist, M 2 .instr );
backpatch(l, nextinstr );

*/

logical_AND_expression:
                        inclusive_OR_expression
                            { 
                                $$ = $1;
                            }
                        | logical_AND_expression LOGICAL_AND M inclusive_OR_expression
                            { 
                                $1->toBool(), $4->toBool();
                                $$ = new Expression();
                                $$->type = Expression::BOOLEAN;
                                backpatch($1->trueList, $3);
                                $$->trueList = $4->trueList;
                                $$->falseList = merge($1->falseList, $4->falseList);
                            }
                        ;

logical_OR_expression:
                        logical_AND_expression
                            { 
                                $$ = $1;
                            }
                        | logical_OR_expression LOGICAL_OR M logical_AND_expression
                            { 
                                $1->toBool(), $4->toBool();
                                $$ = new Expression();
                                $$->type = Expression::BOOLEAN;
                                backpatch($1->falseList, $3);
                                $$->trueList = merge($1->trueList, $4->trueList);
                                $$->falseList = $4->falseList;
                            }
                        ;

conditional_expression:
                        logical_OR_expression
                            { 
                                $$ = $1;
                            }
                        | logical_OR_expression N QUESTION_MARK M expression N COLON M conditional_expression
                            { 
                                $$->symbol = gentemp($5->symbol->type->type);
                                emit("=", $$->symbol->name, $9->symbol->name);
                                list<int> l = makeList(nextInstruction());
                                emit("goto", "");
                                backpatch($6->nextList, nextInstruction());
                                emit("=", $$->symbol->name, $5->symbol->name);
                                l = merge(l, makeList(nextInstruction()));
                                emit("goto", "");
                                backpatch($2->nextList, nextInstruction());
                                $1->toBool();
                                backpatch($1->trueList, $4);
                                backpatch($1->falseList, $8);
                                backpatch(l, nextInstruction());
                            }
                        ;

assignment_expression:
                        conditional_expression
                            { 
                                $$ = $1;
                            }
                        | unary_expression assignment_operator assignment_expression
                            { 
                                if($1->type == Array::ARRAY) {
                                    $3->symbol = $3->symbol->convert($1->subArrayType->type);
                                    emit("[]=", $1->symbol->name, $1->temp->name, $3->symbol->name);
                                } else if($1->type == Array::POINTER) {
                                    $3->symbol = $3->symbol->convert($1->temp->type->type);
                                    emit("*=", $1->temp->name, $3->symbol->name);
                                } else {
                                    $3->symbol = $3->symbol->convert($1->symbol->type->type);
			                        emit("=", $1->symbol->name, $3->symbol->name);
                                }
                                $$ = $3;
                            }
                        ;

assignment_operator:
                    ASSIGN
                        { 
                        }
                    | MULTIPLY_ASSIGN
                        { 
                        }
                    | DIVIDE_ASSIGN
                        { 
                        }
                    | MODULUS_ASSIGN
                        { 
                        }
                    | ADD_ASSIGN
                        { 
                        }
                    | SUBTRACT_ASSIGN
                        { 
                        }
                    | LEFT_SHIFT_ASSIGN
                        { 
                        }
                    | RIGHT_SHIFT_ASSIGN
                        { 
                        }
                    | AND_ASSIGN
                        { 
                        }
                    | XOR_ASSIGN
                        { 
                        }
                    | OR_ASSIGN
                        { 
                        }
                    ;

expression:
            assignment_expression
                { 
                    $$ = $1;
                }
            | expression COMMA assignment_expression
                {
                }
            ;

constant_expression:
                    conditional_expression
                        {
                        }
                    ;

/* Declarations */

declaration:
            declaration_specifiers init_declarator_list_opt SEMICOLON
                {
                }
            ;

init_declarator_list_opt:
                            init_declarator_list
                                {
                                }
                            |
                                {
                                }
                            ;

declaration_specifiers:
                        storage_class_specifier declaration_specifiers_opt
                            {
                            }
                        | type_specifier declaration_specifiers_opt
                            {
                            }
                        | type_qualifier declaration_specifiers_opt
                            {
                            }
                        | function_specifier declaration_specifiers_opt
                            {
                            }
                        ;

declaration_specifiers_opt:
                            declaration_specifiers
                                {
                                }
                            |
                                {
                                }
                            ;

init_declarator_list:
                        init_declarator
                            {
                            }
                        | init_declarator_list COMMA init_declarator
                            {
                            }
                        ;

init_declarator:
                declarator
                    { 
                        $$ = $1;
                    }
                | declarator ASSIGN initialiser
                    { 
                        if($3->initialValue != "") 
                            $1->initialValue = $3->initialValue;
		                emit("=", $1->name, $3->name);
                    }
                ;

storage_class_specifier:
                        EXTERN
                            {
                            }
                        | STATIC
                            {
                            }
                        | AUTO
                            {
                            }
                        | REGISTER
                            {
                            }
                        ;

type_specifier:
                _VOID
                    { 
                        currentType = SymbolType::VOID;
                    }
                | _CHAR
                    { 
                        currentType = SymbolType::CHAR;
                    }
                | SHORT
                    {
                    }
                | _INT
                    { 
                        currentType = SymbolType::INT;
                    }
                | LONG
                    {
                    }
                | _FLOAT
                    { 
                        currentType = SymbolType::FLOAT;
                    }
                | _DOUBLE
                    {
                    }
                | SIGNED
                    {
                    }
                | UNSIGNED
                    {
                    }
                | BOOL
                    {
                    }
                | COMPLEX
                    {
                    }
                | IMAGINARY
                    {
                    }
                | enum_specifier 
                    {
                    }
                ;

specifier_qualifier_list:
                            type_specifier specifier_qualifier_list_opt
                                { 
                                }
                            | type_qualifier specifier_qualifier_list_opt
                                { 
                                }
                            ;

specifier_qualifier_list_opt:
                                specifier_qualifier_list
                                    { 
                                    }
                                | 
                                    { 
                                    }
                                ;

enum_specifier:
                ENUM identifier_opt LEFT_CURLY_BRACE enumerator_list RIGHT_CURLY_BRACE 
                    { 
                    }
                | ENUM identifier_opt LEFT_CURLY_BRACE enumerator_list COMMA RIGHT_CURLY_BRACE
                    { 
                    }
                | ENUM IDENTIFIER
                    { 
                    }
                ;

identifier_opt:
                IDENTIFIER 
                    { 
                    }
                | 
                    { 
                    }
                ;

enumerator_list:
                enumerator 
                    { 
                    }
                | enumerator_list COMMA enumerator
                    { 
                    }
                ;

enumerator:
            IDENTIFIER 
                { 
                }
            | IDENTIFIER ASSIGN constant_expression
                { 
                }
            ;

type_qualifier:
                CONST
                    { 
                    }
                | RESTRICT
                    { 
                    }
                | VOLATILE
                    { 
                    }
                ;

function_specifier:
                    INLINE
                        { 
                        }
                    ;

declarator:
            pointer direct_declarator
                { 
                    SymbolType *it = $1;
                    while(it->arrayType != NULL) 
                        it = it->arrayType;
                    it->arrayType = $2->type;
                    $$ = $2->update($1);
                }
            | direct_declarator
                { 
                }
            ;

/*
Whenever the scope changes, create a new nested table accordingly. 
*/

change_scope:
                    {
                        if(currentSymbol->nestedTable == NULL)
                            changeTable(new SymbolTable(""));
                        else {
                            changeTable(currentSymbol->nestedTable);
                            emit("label", currentTable->name);
                        }
                    }
	            ;

/*
Declarations
*/

direct_declarator:
                    IDENTIFIER 
                        { 
                            $$ = $1->update(new SymbolType(currentType)); // update type to the last type seen
                            currentSymbol = $$;
                        }
                    | LEFT_PARENTHESIS declarator RIGHT_PARENTHESIS
                        { 
                            $$ = $2;
                        }
                    | direct_declarator LEFT_SQUARE_BRACE type_qualifier_list assignment_expression RIGHT_SQUARE_BRACE
                        { 
                        }
                    | direct_declarator LEFT_SQUARE_BRACE type_qualifier_list RIGHT_SQUARE_BRACE
                        { 
                        }
                    | direct_declarator LEFT_SQUARE_BRACE assignment_expression RIGHT_SQUARE_BRACE
                        { 
                            SymbolType *it1 = $1->type, *it2 = NULL;
                            while(it1->type == SymbolType::ARRAY) { // go to the base level of a nested type
                                it2 = it1;
                                it1 = it1->arrayType;
                            }
                            if(it2 != NULL) { // nested array case
                                // another level of nesting with base as it1 and width the value of assignment_expression
                                it2->arrayType =  new SymbolType(SymbolType::ARRAY, it1, atoi($3->symbol->initialValue.c_str()));	
                                $$ = $1->update($1->type);
                            }
                            else { // fresh array
                                // create a new array with base as type of direct_declarator and width the value of assignment_expression
                                $$ = $1->update(new SymbolType(SymbolType::ARRAY, $1->type, atoi($3->symbol->initialValue.c_str())));
                            }
                        }
                    | direct_declarator LEFT_SQUARE_BRACE RIGHT_SQUARE_BRACE
                        { 
                            // same as the previous rule, just we dont know the size so put it as 0
                            SymbolType *it1 = $1->type, *it2 = NULL;
                            while(it1->type == SymbolType::ARRAY) { // go to the base level of a nested type
                                it2 = it1;
                                it1 = it1->arrayType;
                            }
                            if(it2 != NULL) { // nested array case
                                // another level of nesting with base as it1 and width the value of assignment_expression
                                it2->arrayType =  new SymbolType(SymbolType::ARRAY, it1, 0);	
                                $$ = $1->update($1->type);
                            }
                            else { // fresh array
                                // create a new array with base as type of direct_declarator and width the value of assignment_expression
                                $$ = $1->update(new SymbolType(SymbolType::ARRAY, $1->type, 0));
                            }
                        }
                    | direct_declarator LEFT_SQUARE_BRACE STATIC type_qualifier_list assignment_expression RIGHT_SQUARE_BRACE
                        { 
                        }
                    | direct_declarator LEFT_SQUARE_BRACE STATIC assignment_expression RIGHT_SQUARE_BRACE
                        { 
                        }
                    | direct_declarator LEFT_SQUARE_BRACE type_qualifier_list STATIC assignment_expression RIGHT_SQUARE_BRACE
                        { 
                        }
                    | direct_declarator LEFT_SQUARE_BRACE type_qualifier_list MULTIPLY RIGHT_SQUARE_BRACE
                        { 
                        }
                    | direct_declarator LEFT_SQUARE_BRACE MULTIPLY RIGHT_SQUARE_BRACE
                        { 
                        }
                    | direct_declarator LEFT_PARENTHESIS change_scope parameter_type_list RIGHT_PARENTHESIS
                        { 
                            // function declaration
                            currentTable->name = $1->name;
                            if($1->type->type != SymbolType::VOID) {
                                // set type of return value
                                currentTable->lookup("return")->update($1->type);
                            }
                            // move back to the global table and set the nested table for the function
                            $1->nestedTable = currentTable;
                            currentTable->parent = globalTable;
                            changeTable(globalTable);
                            currentSymbol = $$;
                        }
                    | direct_declarator LEFT_PARENTHESIS identifier_list RIGHT_PARENTHESIS
                        { 
                        }
                    | direct_declarator LEFT_PARENTHESIS change_scope RIGHT_PARENTHESIS
                        { 
                            // same as the previous rule
                            currentTable->name = $1->name;
                            if($1->type->type != SymbolType::VOID) {
                                // set type of return value
                                currentTable->lookup("return")->update($1->type);
                            }
                            // move back to the global table and set the nested table for the function
                            $1->nestedTable = currentTable;
                            currentTable->parent = globalTable;
                            changeTable(globalTable);
                            currentSymbol = $$;
                        }
                    ;

type_qualifier_list_opt:
                        type_qualifier_list
                            { 
                            }
                        |
                            { 
                            }
                        ;

/* assignment_expression_opt:
                            assignment_expression
                                { 
                                }
                            |
                                { 
                                }
                            ; */

/* identifier_list_opt:
                    identifier_list
                        { 
                        }
                    |
                        { 
                        }
                    ; */

/*

Pointer declarations
Generate new symbol with type pointer

*/

pointer:
        MULTIPLY type_qualifier_list_opt
            { 
                // fresh pointer
                $$ = new SymbolType(SymbolType::POINTER);
            }
        | MULTIPLY type_qualifier_list_opt pointer
            { 
                // nested pointer
                $$ = new SymbolType(SymbolType::POINTER, $3);
            }
        ;

type_qualifier_list:
                    type_qualifier
                        { 
                        }
                    | type_qualifier_list type_qualifier
                        { 
                        }
                    ;

parameter_type_list:
                    parameter_list
                        { 
                        }
                    | parameter_list COMMA ELLIPSIS
                        { 
                        }
                    ;

parameter_list:
                parameter_declaration
                    { 
                    }
                | parameter_list COMMA parameter_declaration
                    { 
                    }
                ;

parameter_declaration:
                        declaration_specifiers declarator
                            { 
                            }
                        | declaration_specifiers
                            { 
                            }
                        ;

identifier_list:
                IDENTIFIER 
                    { 
                    }
                | identifier_list COMMA IDENTIFIER
                    { 
                    }
                ;

type_name:
            specifier_qualifier_list
                { 
                }
            ;

initialiser:
            assignment_expression
                { 
                    $$ = $1->symbol;
                }
            | LEFT_CURLY_BRACE initialiser_list RIGHT_CURLY_BRACE
                { 
                }  
            | LEFT_CURLY_BRACE initialiser_list COMMA RIGHT_CURLY_BRACE
                { 
                }
            ;

initialiser_list:
                    designation_opt initialiser
                        { 
                        }
                    | initialiser_list COMMA designation_opt initialiser
                        { 
                        }
                    ;

designation_opt:
                designation
                    { 
                    }
                |
                    { 
                    }
                ;

designation:
            designator_list ASSIGN
                { 
                }
            ;

designator_list:
                designator
                    { 
                    }
                | designator_list designator
                    { 
                    }
                ;

designator:
            LEFT_SQUARE_BRACE constant_expression RIGHT_SQUARE_BRACE
                { 
                }
            | DOT IDENTIFIER
                { 
                }   
            ;

/* Statements */

statement:
            labeled_statement
                { 
                }
            | compound_statement
                { 
                    $$ = $1; 
                }
            | expression_statement
                { 
                    $$ = new Statement();
                    $$->nextList = $1->nextList;
                }
            | selection_statement
                { 
                    $$ = $1;
                }
            | iteration_statement
                { 
                    $$ = $1;
                }
            | jump_statement
                { 
                    $$ = $1;
                }
            ;

labeled_statement:
                    IDENTIFIER COLON statement
                        { 
                        }
                    | CASE constant_expression COLON statement
                        { 
                        }    
                    | DEFAULT COLON statement
                        { 
                        }
                    ;

/*

Used to change the symbol table when a new block is encountered
Helps create a hierarchy of symbol tables

*/

change_block: 
                    {
                        string name = currentTable->name + "_" + toString(tableCount);
                        tableCount++;
                        Symbol *s = currentTable->lookup(name); // create new entry in symbol table
                        s->nestedTable = new SymbolTable(name, currentTable);
                        s->type = new SymbolType(SymbolType::BLOCK);
                        currentSymbol = s;
                    } 
                ;

compound_statement:
                    LEFT_CURLY_BRACE change_block change_scope block_item_list_opt RIGHT_CURLY_BRACE
                        { 
                            $$ = $4;
                            changeTable(currentTable->parent); // block over, move back to the parent table
                        }
                    ;

block_item_list_opt:
                    block_item_list
                        { 
                            $$ = $1;
                        }
                    |
                        { 
                            $$ = new Statement();
                        }
                    ;

block_item_list:
                block_item
                    {
                        $$ = $1;
                    }
                | block_item_list M block_item
                    { 
                        $$ = $3;
                        // after completion of block_item_list(1) we move to block_item(3)
                        backpatch($1->nextList,$2);
                    }
                ;

block_item:
            declaration
                { 
                    $$ = new Statement();
                }
            | statement
                { 
                    $$ = $1;
                }
            ;

expression_statement:
                        expression_opt SEMICOLON
                            { 
                                $$ = $1;
                            }
                        ;

expression_opt:
                expression
                    { 
                        $$ = $1;
                    }
                |
                    { 
                        $$ = new Expression();
                    }
                ;

/*

IF ELSE

-> the %prec THEN is to remove conflicts during translation

Markers M and guard N have been added as discussed in the class

S -> if (B) M S1 N
backpatch(B.truelist, M.instr )
S.nextlist = merge(B.falselist, merge(S1.nextlist, N.nextlist))

S -> if (B) M 1 S 1 N else M 2 S 2
backpatch(B.truelist, M1.instr )
backpatch(B.falselist, M2.instr )
S.nextlist = merge(merge(S1.nextlist, N.nextlist), S2 .nextlist)

*/

selection_statement:
                    IF LEFT_PARENTHESIS expression RIGHT_PARENTHESIS M statement N %prec THEN
                        { 
                            $$ = new Statement();
                            $3->toBool();
                            backpatch($3->trueList, $5); // if true go to M
                            $$->nextList = merge($3->falseList, merge($6->nextList, $7->nextList)); // exits
                        }
                    | IF LEFT_PARENTHESIS expression RIGHT_PARENTHESIS M statement N ELSE M statement
                        { 
                            $$ = new Statement();
                            $3->toBool();
                            backpatch($3->trueList, $5); // if true go to M
                            backpatch($3->falseList, $9); // if false go to else
                            $$->nextList = merge($10->nextList, merge($6->nextList, $7->nextList)); // exits
                        }
                    | SWITCH LEFT_PARENTHESIS expression RIGHT_PARENTHESIS statement
                        { 
                        }
                    ;

/*

LOOPS

while M1 (B) M2 S1
backpatch(S1.nextlist, M1.instr );
backpatch(B.truelist, M2.instr );
S.nextlist = B.falselist;
emit(”goto”, M1.instr );

do M1 S1 M2 while ( B );
backpatch(B.truelist, M1.instr );
backpatch(S1 .nextlist, M2.instr );
S.nextlist = B.falselist;

for ( E1 ; M1 B ; M2 E2 N ) M3 S1
backpatch(B.truelist, M3.instr );
backpatch(N.nextlist, M1.instr );
backpatch(S1.nextlist, M2.instr );
emit(”goto” M2.instr );
S.nextlist = B.falselist;

*/

iteration_statement:
                    WHILE M LEFT_PARENTHESIS expression RIGHT_PARENTHESIS M statement
                        { 
                            $$ = new Statement();
                            $4->toBool();
                            backpatch($7->nextList, $2); // after statement go back to M1
                            backpatch($4->trueList, $6); // if true go to M2
                            $$->nextList = $4->falseList; // exit if false
                            emit("goto", toString($2));
                        }
                    | DO M statement M WHILE LEFT_PARENTHESIS expression RIGHT_PARENTHESIS SEMICOLON
                        { 
                            $$ = new Statement();
                            $7->toBool();
                            backpatch($7->trueList, $2); // if true go back to M1
                            backpatch($3->nextList, $4); // after statement is executed go to M2
                            $$->nextList = $7->falseList; // exit if false
                        }
                    | FOR LEFT_PARENTHESIS expression_opt SEMICOLON M expression_opt SEMICOLON M expression_opt N RIGHT_PARENTHESIS M statement
                        { 
                            $$ = new Statement();
                            $6->toBool();
                            backpatch($6->trueList, $12); // if true go to M3 (loop body)
                            backpatch($10->nextList, $5); // after N go to M1 (condition check)
                            backpatch($13->nextList, $8); // after S1 (loop body) go to M2 (increment/decrement/any other operation)
                            emit("goto", toString($8));
                            $$->nextList = $6->falseList; // exit if false
                        }
                    | FOR LEFT_PARENTHESIS declaration expression_opt SEMICOLON expression_opt RIGHT_PARENTHESIS statement
                        { 
                        }
                    ;

jump_statement:
                GOTO IDENTIFIER SEMICOLON
                    { 
                    }    
                | CONTINUE SEMICOLON
                    { 
                    }
                | BREAK SEMICOLON
                    { 
                    }
                | RETURN expression_opt SEMICOLON
                    { 
                        $$ = new Statement();
                        if($2->symbol != NULL) {
                            emit("return", $2->symbol->name); // emit the current symbol name at return if it exists otherwise empty
                        } else {
                            emit("return", "");
                        }
                    }
                ;

/* External definitions */

translation_unit:
                    external_declaration
                        { 
                        }
                    | translation_unit external_declaration
                        { 
                        }
                    ;

external_declaration:
                        function_definition
                            { 
                            }
                        | declaration
                            { 
                            }
                        ;

function_definition: // to prevent block change here which is there in the compound statement grammar rule
                     // this rule is slightly modified by expanding the original compound statement rule over here
                    declaration_specifiers declarator declaration_list_opt change_scope LEFT_CURLY_BRACE block_item_list_opt RIGHT_CURLY_BRACE
                        { 
                            tableCount = 0;
                            $2->isFunction = true;
                            changeTable(globalTable);
                        }
                    ;

declaration_list_opt:
                        declaration_list
                            { 
                            }
                        |
                            { 
                            }
                        ;

declaration_list:
                    declaration
                        { 
                        }
                    | declaration_list declaration
                        { 
                        }
                    ;

%%

void yyerror(string s) {
    printf("ERROR [Line %d] : %s\n", yylineno, s.c_str());
}