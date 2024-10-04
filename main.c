#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BATTERY_CAPACITY_PATH "/sys/class/power_supply/BAT0/capacity"
#define BATTERY_STATUS_PATH "/sys/class/power_supply/BAT0/status"

void read_file_to_buf(const char *path, char *buffer, size_t size) {
  FILE *file = fopen(path, "r");
  if (file == NULL) {
    perror(path);
    exit(-1);
  }

  if (fgets(buffer, size, file) == NULL) {
    perror(path);
    exit(-1);
  }

  fclose(file);
}

const bool cmp_string(const char *str1, const char *str2) {
  if (strcmp(str1, str2) == 0) {
    return true;
  }
  return false;
}

// Exit if the [value] is NULL with an message
void assert_not_null(const void *value, const char *msg) {
  if (value == NULL) {
    puts("Assert Failed\n");
    printf("The value is null: %s\n", msg);
    exit(-1);
  }
}

void assert_truthy(bool truthy, const char *msg) {
  if (truthy) {
    puts("Assert Failed\n");
    printf("%s\n", msg);
    exit(-1);
  }
}

int main(int argc, char *argv[]) {
  char capacity_buffer[4];
  char status_buffer[12];

  const char *home_path = getenv("HOME");
  assert_not_null(home_path, "error getting HOME env variable");

  char *config_path;
  assert_truthy(0 > asprintf(&config_path, "%s/%s", home_path, "batmon.ini"),
                "Failed to format string for config file path");

  const FILE *config_file = fopen(config_path, "r");
  if (!config_file) {
    printf("Creating config file at: %s\n", config_path);
    FILE *write_config_file = fopen(config_path, "w");
    assert_not_null(write_config_file,
                    "Failed to create config file for writing");

    // Write the config options
    const char *opts[7];
    opts[0] = "[Batmon]\n";

    opts[1] = "# Warn if battery is blow or equal to 50%";
    opts[2] = "Half = 50\n";

    opts[3] = "# Warn if battery is blow or equal to 25%";
    opts[4] = "Mid = 25\n";

    opts[5] = "# Warn if battery is blow or equal to 10%";
    opts[6] = "Low = 10";

    for (int i = 0; i < 7; i++) {
      assert_truthy(0 > fprintf(write_config_file, "%s\n", opts[i]),
                    "Failed to write to config file");
    }

    puts("");
    puts("Half = 50");
    puts("Mid  = 25");
    puts("Low  = 10");

    printf("You can change the config optins here: %s\n", config_path);
    puts("");
  }

  free(config_path);

  if (argc >= 2) {
    for (int i = 1; i < argc; i++) {
      if (cmp_string(argv[i], "s") || cmp_string(argv[i], "status")) {
        read_file_to_buf(BATTERY_CAPACITY_PATH, capacity_buffer,
                         sizeof(capacity_buffer));
        read_file_to_buf(BATTERY_STATUS_PATH, status_buffer,
                         sizeof(status_buffer));

        printf("Battery Capacity: %s\n", capacity_buffer);
        printf("Battery Status: %s\n", status_buffer);
        return 0;
      }

      // Exit if command doesn't exists
      printf("Command not found: %s", argv[i]);
      exit(-1);
    }
  }

  while (true) {
    printf("batmon: started in deamon mode\n");

    read_file_to_buf(BATTERY_CAPACITY_PATH, capacity_buffer,
                     sizeof(capacity_buffer));
    read_file_to_buf(BATTERY_STATUS_PATH, status_buffer, sizeof(status_buffer));

    printf("Battery Capacity: %s\n", capacity_buffer);
    printf("Battery Status: %s", status_buffer);
    printf("\n");

    sleep(5);
  }

  return 0;
}
