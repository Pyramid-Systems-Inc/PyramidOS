#include "string.h"

void *memset(void *dest, int val, size_t len)
{
    unsigned char *ptr = (unsigned char *)dest;
    while (len-- > 0)
    {
        *ptr++ = (unsigned char)val;
    }
    return dest;
}

void *memcpy(void *dest, const void *src, size_t len)
{
    char *d = (char *)dest;
    const char *s = (const char *)src;
    while (len--)
    {
        *d++ = *s++;
    }
    return dest;
}

size_t strlen(const char *str)
{
    size_t len = 0;
    while (str[len])
        len++;
    return len;
}

int strcmp(const char *s1, const char *s2)
{
    while (*s1 && (*s1 == *s2))
    {
        s1++;
        s2++;
    }
    return *(const unsigned char *)s1 - *(const unsigned char *)s2;
}

// Compare up to n characters
int strncmp(const char *s1, const char *s2, size_t n)
{
    while (n > 0 && *s1 && (*s1 == *s2))
    {
        s1++;
        s2++;
        n--;
    }
    if (n == 0)
        return 0;
    return *(const unsigned char *)s1 - *(const unsigned char *)s2;
}

// Copy string
char *strcpy(char *dest, const char *src)
{
    char *saved = dest;
    while (*src)
    {
        *dest++ = *src++;
    }
    *dest = 0;
    return saved;
}

// Concatenate string
char *strcat(char *dest, const char *src)
{
    char *saved = dest;
    while (*dest)
        dest++; // Go to end of dest
    while (*src)
    {
        *dest++ = *src++;
    }
    *dest = 0;
    return saved;
}