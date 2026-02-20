#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *read_line(void)
{
	constexpr size_t initial_capacity = 16;
	size_t buffer_capacity = initial_capacity;
	size_t input_length = 0;

	char *buffer = malloc(buffer_capacity);

	if (!buffer) {
		printf("Memory allocation for input buffer failed. Quitting...\n");
		goto ERROR;
	}

	int input = 0;

	while ((input = getchar()) != '\n' && input != EOF) {
		if (buffer_capacity > SIZE_MAX / 2) {
			printf("Input overflowed!\n");
			goto ERROR;
		}

		if (input_length + 1 >= buffer_capacity) {
			size_t new_capacity = buffer_capacity * 2;
			char *temp = realloc(buffer, new_capacity);

			if (!temp) {
				printf("Memory re-allocation for input buffer failed. Quitting...\n");
				goto ERROR;
			}

			buffer = temp;
			buffer_capacity = new_capacity;

		}

		buffer[input_length++] = (char)input;
	}

	buffer[input_length] = '\0';

	return buffer;

ERROR:
	free(buffer);
	buffer = nullptr;

	return nullptr;
}

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
