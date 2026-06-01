#include <linux/errno.h>
#include <linux/fs.h>
#include <linux/kernel.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/uaccess.h>

extern int ec_read(u8 addr, u8 *val);
extern int ec_write(u8 addr, u8 val);

#define EC_SET_PROFILE 0x4422
#define EC_GET_PROFILE 0x4423
#define EC_GET_FAN_SPEED 0x4424

static long hp_ec_ioctl(struct file *file, unsigned int cmd,
                        unsigned long arg) {
  int ret;

  if (cmd == EC_GET_FAN_SPEED) {
    u8 speed_val = 0;
    ret = ec_read(17, &speed_val);
    if (ret < 0)
      return ret;

    return speed_val;
  }
  if (cmd == EC_GET_PROFILE) {
    u8 v1 = 0, v2 = 0;
    u8 target_v1 = 0, target_v2 = 0;
    int profile = 0;
    bool requires_v1_fix = false;

    ret = ec_read(89, &v1);
    if (ret < 0)
      return ret;

    if (v1 == 0x05) {
      profile = 0;
      target_v2 = 0x41;
    } else if (v1 == 0x04) {
      profile = 1;
      target_v2 = 0x40;
    } else if (v1 == 0x06) {
      profile = 2;
      target_v2 = 0x43;
    } else if (v1 == 0x07) {
      profile = 3;
      target_v2 = 0x42;
    } else if (v1 == 0x08) {
      profile = 4;
      target_v2 = 0x44;
    } else {
      profile = 0;
      target_v1 = 0x05;
      target_v2 = 0x41;
      requires_v1_fix = true;
    }

    if (requires_v1_fix) {
      pr_info("hp_ec: Reg 89 unknown (0x%02x). Falling back to Balanced.\n",
              v1);
      ec_write(89, target_v1);
      v1 = target_v1;
    }

    ret = ec_read(41, &v2);
    if (ret >= 0 && v2 != target_v2) {
      pr_info("hp_ec: Reg 41 out of sync (0x%02x). Syncing to 0x%02x to match "
              "Reg 89.\n",
              v2, target_v2);
      ec_write(41, target_v2);
    }

    return profile;
  }

  if (cmd == EC_SET_PROFILE) {
    u8 v1, v2;
    switch (arg) {
    case 0:
      v1 = 0x05;
      v2 = 0x41;
      break;
    case 1:
      v1 = 0x04;
      v2 = 0x40;
      break;
    case 2:
      v1 = 0x06;
      v2 = 0x43;
      break;
    case 3:
      v1 = 0x07;
      v2 = 0x42;
      break;
    case 4:
      v1 = 0x08;
      v2 = 0x44;
      break;
    default:
      return -EINVAL;
    }

    u8 reg1 = 89;
    u8 reg2 = 41;
    u8 old_v1 = 0, new_v1 = 0, old_v2 = 0, new_v2 = 0;

    // Process Register 89
    ret = ec_read(reg1, &old_v1);
    if (ret < 0)
      return ret;
    ret = ec_write(reg1, v1);
    if (ret < 0)
      return ret;
    ret = ec_read(reg1, &new_v1);
    if (ret < 0)
      return ret;

    // Process Register 41
    ret = ec_read(reg2, &old_v2);
    if (ret < 0)
      return ret;
    ret = ec_write(reg2, v2);
    if (ret < 0)
      return ret;
    ret = ec_read(reg2, &new_v2);
    if (ret < 0)
      return ret;

    pr_info("hp_ec: Profile %lu. REG %u changed (0x%02x -> 0x%02x). REG %u "
            "changed (0x%02x -> 0x%02x).\n",
            arg, reg1, old_v1, new_v1, reg2, old_v2, new_v2);

    return 0;
  }

  return -ENOTTY;
}

static const struct file_operations hp_ec_fops = {
    .owner = THIS_MODULE,
    .unlocked_ioctl = hp_ec_ioctl,
};

static struct miscdevice hp_ec_misc = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = "hp_ec_thermal",
    .fops = &hp_ec_fops,
};

static int __init hp_ec_init(void) {
  int ret = misc_register(&hp_ec_misc);
  if (ret) {
    pr_err("hp_ec: Failed to register misc device\n");
    return ret;
  }
  return 0;
}

static void __exit hp_ec_exit(void) { misc_deregister(&hp_ec_misc); }

module_init(hp_ec_init);
module_exit(hp_ec_exit);

MODULE_AUTHOR("Salvatore Giarracca");
MODULE_DESCRIPTION("HP Envy x360 15-ew0xxx EC Thermal Control");
MODULE_LICENSE("GPL");
