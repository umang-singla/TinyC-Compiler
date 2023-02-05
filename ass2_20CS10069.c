#include "myl.h"

#define BUFF 100                                  // buffer size for various operations
#define PRECISION 6                               // precision for printing floating point numbers

/*
    * printStr: prints a string to the console
    * @str: string to be printed
    * @return: Number of characters printed
*/
int printStr(char *str)
{
    int i = 0;                                    // counter for string length
    while(*(str+i) != '\0')                       // while end of string is not encountered
    {
        i++;                                      // keep incrementing the counter
    }

    __asm__ __volatile__(
        "movl $1, %%eax\n\t"                      // 1 <-- eax, implies calling function write
        "movq $1, %%rdi\n\t"                      // 1 <-- rdi, implies printing to stdout
        "syscall\n\t"                             // Call the write function
        :
        :"S"(str), "d"(i)                         // Pass the parameters to write function, 'str' to esi and 'i' to edx
    );

    return i;                                     // return the number of characters printed
}

/*
    * printInt: prints an integer to the console
    * @n: integer to be printed
    * @return: Number of characters printed if successful, ERR otherwise
*/
int printInt(int n)
{
    char buff[BUFF], zero = '0';                // buffer to store the integer in string format, and the zero character
    int i = 0;                                  // counter for string length

    long int temp = n;                          // temporary variable to store the integer in long int format, useful when n = INT_MIN

    if(temp==0)                                 // handle the case when the integer is 0
        buff[i++] = zero;
    else{

        if(temp<0){                             // if temp is negative, store the negative sign
            buff[i++] = '-';                    // buff[0] = '-'
            temp = -temp;                       // make temp positive
        }

        while(temp>0){                          // while has digits to be printed
            buff[i++] = (char)(temp%10 + '0');  // store the remainder of n/10 in the buffer
            temp /= 10;                         // divide temp by 10
        }

        int j;                                  // iterator to the start of the buffer
        if(buff[0] == '-')                      // if temp is negative, digits start from index 1
            j = 1;
        else                                    // if temp is positive, digits start from index 0
            j = 0;

        int k = i-1;                            // iterator to the end of the buffer
        while(j<k){                             // while there are digits to be swapped
            char temp = buff[j];                // swap the digits
            buff[j] = buff[k];
            buff[k] = temp;
            j++;                                // increment j
            k--;                                // decrement k
        }
    }

    __asm__ __volatile__ (
        "movl $1, %%eax\n\t"                    // 1 <-- eax, implies calling function write
        "movq $1, %%rdi\n\t"                    // 1 <-- rdi, implies printing to stdout
        "syscall\n\t"                           // Call the write function
        :
        :"S"(buff), "d"(i)                      // Pass the parameters to write function, 'buff' to esi and 'i' to edx
    ); 

    return i;                                   // return the number of characters printed
}

/*
    * readStr: reads a string from the console
    * @str: location to store the string
    * @return: Number of characters read
*/
int readStr(char *str)
{
    int _len = 0;                               // length of the string

    __asm__ __volatile__ (
        "movl $0, %%eax \n\t"                   // 0 <-- eax, implies calling function read
        "movq $0, %%rdi \n\t"                   // 0 <-- rdi, implies reading from stdin
        "syscall \n\t"                          // Call the read function
        : "=a"(_len)                            // Store the number of characters read in _len
        :"S"(str), "d"(BUFF));                  // Pass the parameters to read function, 'str' to esi and 'BUFF' to edx

    return _len;                                // return the length of the string
}

/*
    * readInt: reads an integer from the console
    * @n: integer to be read
    * @return: OK if successful, ERR otherwise
*/
int readInt(int *n)
{
    char buff[BUFF];                            // buffer to store the integer in string format 
    int _len = readStr(buff);                   // read the integer as string from the console

    if(_len<0)                                  // if error in reading the integer (length read is negative)
        return ERR;                             // return error

    long int _num = 0;                          // number to be read from the string
    int i=0;                                    // and iterator for the buffer
    _Bool neg=0;                                // flag to indicate if the number is negative

    if(buff[0]=='-')                            // if the number is negative
        neg=1, i=1;                             // set the flag and increment the iterator
    
    if(buff[0]=='+')                            // if the first character is '+'
        i=1;                                    // increment the iterator

    for(; i < _len-1; ++i)                      // for each character in buffer
    {
        // if the character is a dot or a space or newline or tab, break
        if(buff[i] == '.' || buff[i]==' ' || buff[i]=='\n' || buff[i]=='\t') 
            break;

        if(buff[i]<'0' || buff[i]>'9')          // if the character is not a digit
            return ERR;                         // return error

        _num*= (long int)10;                    // multiply the number by 10
        _num += (long int)(buff[i]-'0');        // add the digit to the number
    }

    if(neg)                                     // if the number is negative
        _num = -_num;                           // make the number negative

    // if the number is out of range of int
    if(_num > __INT_MAX__ || _num < ((long int)-1-(long int)__INT_MAX__))        
        return ERR;                             // return error
    
    *n = _num;                                  // store the number in the argument
    return OK;                                  // return success
}

/*
    * readFlt: reads a floating point number from the console
    * @f: floating point number to be read
    * @return: OK if successful, ERR otherwise
*/
int readFlt(float *f)
{
    char buff[BUFF];                            // buffer to store the floating point number in string format
    int _len = readStr(buff);                   // read the floating point number as string from the console

    if(_len < 0)                                // if error in reading the floating point number (length read is negative)
        return ERR;                             // return error

    int i=0;                                    // iterator for the buffer
    _Bool neg=0;                                // flag to indicate if the number is negative
    float _num = 0;                             // number to be read

    if(buff[0]=='-')                            // if the number is negative
        neg=1, i=1;                             // set the flag and increment the iterator

    for(; i < _len-1; ++i)                      // for each character in buffer
    {
        // if the character is a dot or a space or newline or tab
        if(buff[i]=='.' || buff[i]==' ' || buff[i]=='\n' || buff[i]=='\t')
            break;                              // break from the loop
        
        if(buff[i]<'0' || buff[i]>'9')          // if the character is not a digit
            return ERR;                         // return error

        _num*=10;                               // multiply the number by 10, to shift the coefficient of power of 10
        _num += (int)(buff[i]-'0');             // add the digit to the number
    }

    if(buff[i]!='.')
    {
        if(neg)                                 // if the number is negative
            _num = -_num;                       // make the number negative
        *f = _num;                              // store the number in the argument
        return OK;                              // return success
    }

    int temp = 1;                               // temporary variable to store the power of 10
    i++;                                        // increment the iterator

    for(; i < _len-1; ++i)                      // for each character in buffer (left to be read yet)
    {
        // if the character is a space or newline or tab
        if(buff[i]==' ' || buff[i]=='\n' || buff[i]=='\t')
            break;                              // break from the loop

        if(buff[i]<'0' || buff[i]>'9')          // if the character is not a digit
            return ERR;                         // return error

        temp *= 10;                             // multiply the power of 10 (temp) by 10
                                                // add the digit to the number (_num)
        _num += (double)((int)(buff[i]-'0'))/(double)temp;                    
    }

    if(neg)                                     // if the number is negative
        _num = -_num;                           // make the number negative

    *f = _num;                                  // store the number in the argument
    return OK;                                  // return success
}

/*
    * printFlt: prints a floating point number to the console
    * @f: floating point number to be printed
    * @return: Number of characters printed if successful, ERR otherwise
*/
int printFlt(float f)
{
    _Bool neg=0;                               // Flag, 0 if f is positive, 1 if it is negative 

    if(f<0.0)                                  // If f is negative 
    {
        printStr("-");                         // print the minus sign if the number is negative
        f = -f;                                // make the number positive
        neg=1;                                 // make neg flag as 1
    }

    int intPart = (int)f;                       // Integer part of the floating point decimal
    int _len = printInt(intPart);               // Print the integer part and store it's length

    f -= intPart;                               // Get the decimal part by substracting integer part
    if(f<0)                                     // If the number is still negative (after printing integer part),
        f = -f;                                 // make it positive, because decimal part is always positive

    _len+=printStr(".");                        // Print the decimal, and increment the length

    char decPart[10];                           // Buffer to store the decimal part in string format
    for(int i=0; i<PRECISION; ++i)              // For each digit in the decimal part
    {
        f*=10;                                  // Multiply the decimal part by 10
        decPart[i] = (char)((int)f+'0');        // Store the digit in the buffer
        f -= (int)f;                            // Substract the digit from the decimal part
    }
    decPart[PRECISION] = '\0';                  // Null terminate the buffer
    _len += printStr(decPart);                  // Print the decimal part and add it's length

    if(neg)                                     // If the parameter passed was negative,
        _len+=1;                                // Add 1 to the length (for the '-' character)

    return _len;                                // Return the length
}
