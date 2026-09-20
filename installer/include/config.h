#ifndef CONFIG_STRUCT_H_
#define CONFIG_STRUCT_H_

#define TARGET_ID_SIZE 4 // eg. 0x84

struct configuration {
  int config_version;
  int exploit_fixes;
  int mmap_patches;
  int block_updates;
  int disable_aslr;
  int nobd_patches;
  int skip_patches;
  int upload_prx;
  int enable_plugins;
  int show_network_info; // NEW: 0 = hide IP/klog notify, 1 = show
  int show_title_id;     // NEW: 0 = hide title IDs in PKG listings, 1 = show
  char target_id[TARGET_ID_SIZE + 1];
};

#endif
