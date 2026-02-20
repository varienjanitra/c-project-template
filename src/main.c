#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "main.h"

int main(void)
{
	int status = EXIT_FAILURE;

	if (printf("Good morning! What's your name? ") < 0) {
		goto EXIT;
	}

	char *user_name = read_line();

	if (!user_name) {
		(void)fprintf(stderr, "Fatal Error\n");
		goto EXIT;
	}

	if (printf("Hi, %s! Nice to meet you\n", user_name) < 0) {
		goto CLEANUP;
	}

	status = EXIT_SUCCESS;

CLEANUP:
	free(user_name);
	user_name = nullptr;

EXIT:
	return status;
}
