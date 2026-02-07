#include "common.h"
#include "lib.h"
#include <stdio.h>

void ui_print_progress(const char *label, int percent)
{
	static int last_percent = -1;
	static const char *last_label = NULL;
	if (percent == last_percent && last_label == label) return;
	last_percent = percent;
	last_label = label;

	if (percent < 0) percent = 0;
	int width = 40;
	if (percent > 100) percent = 100;

	printf("\r%-30s [", label);

	const char *parts[] = { " ", "▏", "▎", "▍", "▌", "▋", "▊", "▉" };
	int total_blocks = width * 8;
	int filled_blocks = (percent * total_blocks) / 100;
	int full_blocks = filled_blocks / 8;
	int partial_block = filled_blocks % 8;

	for (int i = 0; i < full_blocks; i++) printf("█");
	if (full_blocks < width)
	{
		printf("%s", parts[partial_block]);
		for (int i = full_blocks + 1; i < width; i++) printf(" ");
	}

	printf("] %3d%%", percent);
	fflush(stdout);
}
