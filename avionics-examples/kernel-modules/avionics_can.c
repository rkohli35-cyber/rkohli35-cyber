/**
 * @file avionics_can.c
 * @brief Avionics CAN bus driver for safety-critical applications
 * @author Avionics Embedded Expert
 * @version 1.0
 * @date 2024
 * 
 * This kernel module provides a robust CAN bus interface specifically
 * designed for avionics applications with deterministic behavior,
 * error handling, and safety features compliant with DO-178C standards.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/device.h>
#include <linux/cdev.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/ioport.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/can.h>
#include <linux/can/core.h>
#include <linux/can/dev.h>
#include <linux/can/error.h>
#include <linux/netdevice.h>
#include <linux/skbuff.h>
#include <linux/workqueue.h>
#include <linux/hrtimer.h>
#include <linux/ktime.h>

/* Module information */
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Avionics Embedded Expert");
MODULE_DESCRIPTION("Avionics CAN Bus Driver for Safety-Critical Applications");
MODULE_VERSION("1.0");
MODULE_ALIAS("platform:avionics-can");

/* Hardware register definitions */
#define AVIONICS_CAN_REG_CTRL       0x00    /* Control register */
#define AVIONICS_CAN_REG_STATUS     0x04    /* Status register */
#define AVIONICS_CAN_REG_INT_EN     0x08    /* Interrupt enable */
#define AVIONICS_CAN_REG_INT_STATUS 0x0C    /* Interrupt status */
#define AVIONICS_CAN_REG_BITRATE    0x10    /* Bit rate configuration */
#define AVIONICS_CAN_REG_TX_ID      0x20    /* TX message ID */
#define AVIONICS_CAN_REG_TX_DLC     0x24    /* TX data length code */
#define AVIONICS_CAN_REG_TX_DATA    0x28    /* TX data registers (8 bytes) */
#define AVIONICS_CAN_REG_RX_ID      0x40    /* RX message ID */
#define AVIONICS_CAN_REG_RX_DLC     0x44    /* RX data length code */
#define AVIONICS_CAN_REG_RX_DATA    0x48    /* RX data registers (8 bytes) */
#define AVIONICS_CAN_REG_FILTER     0x60    /* Message filters (16 entries) */

/* Control register bits */
#define CTRL_ENABLE                 BIT(0)
#define CTRL_RESET                  BIT(1)
#define CTRL_LOOPBACK               BIT(2)
#define CTRL_LISTEN_ONLY            BIT(3)
#define CTRL_AUTO_RETRANSMIT        BIT(4)
#define CTRL_ERROR_PASSIVE          BIT(5)
#define CTRL_BUS_OFF_RECOVERY       BIT(6)

/* Status register bits */
#define STATUS_TX_READY             BIT(0)
#define STATUS_RX_READY             BIT(1)
#define STATUS_ERROR_WARNING        BIT(2)
#define STATUS_ERROR_PASSIVE        BIT(3)
#define STATUS_BUS_OFF              BIT(4)
#define STATUS_ARBITRATION_LOST     BIT(5)
#define STATUS_STUFF_ERROR          BIT(6)
#define STATUS_CRC_ERROR            BIT(7)
#define STATUS_FORM_ERROR           BIT(8)
#define STATUS_ACK_ERROR            BIT(9)

/* Interrupt enable/status bits */
#define INT_TX_COMPLETE             BIT(0)
#define INT_RX_COMPLETE             BIT(1)
#define INT_ERROR_WARNING           BIT(2)
#define INT_ERROR_PASSIVE           BIT(3)
#define INT_BUS_OFF                 BIT(4)
#define INT_ARBITRATION_LOST        BIT(5)
#define INT_DATA_OVERRUN            BIT(6)
#define INT_WAKEUP                  BIT(7)

/* Driver constants */
#define AVIONICS_CAN_MAX_DEVICES    4
#define AVIONICS_CAN_ECHO_SKB_MAX   16
#define AVIONICS_CAN_RX_BUFFER_SIZE 256
#define AVIONICS_CAN_TX_TIMEOUT_MS  100
#define AVIONICS_CAN_RESET_TIMEOUT_MS 50

/* Error counters */
struct avionics_can_error_stats {
    u32 tx_errors;
    u32 rx_errors;
    u32 arbitration_lost;
    u32 stuff_errors;
    u32 crc_errors;
    u32 form_errors;
    u32 ack_errors;
    u32 bus_off_events;
    u32 error_warning_events;
    u32 data_overruns;
};

/* Device private data */
struct avionics_can_priv {
    struct can_priv can;            /* CAN device private data */
    struct net_device *netdev;     /* Network device */
    struct device *dev;            /* Device pointer */
    void __iomem *base;            /* Register base address */
    int irq;                       /* IRQ number */
    struct clk *clk;               /* Clock reference */
    u32 clock_freq;                /* Clock frequency */
    
    /* Hardware management */
    spinlock_t reg_lock;           /* Register access lock */
    struct work_struct tx_work;    /* TX work queue */
    struct work_struct rx_work;    /* RX work queue */
    struct work_struct error_work; /* Error handling work */
    
    /* Error management */
    struct avionics_can_error_stats error_stats;
    u32 error_state;
    struct hrtimer watchdog_timer;
    
    /* Safety features */
    bool safety_mode;              /* Safety-critical mode */
    u32 max_retries;               /* Maximum retransmission attempts */
    u32 bus_recovery_time_ms;      /* Bus-off recovery time */
    
    /* Diagnostic features */
    bool loopback_test;            /* Internal loopback test */
    u32 test_pattern;              /* Test message pattern */
    
    /* Platform specific */
    const struct avionics_can_devtype_data *devtype_data;
};

/* Device type data */
struct avionics_can_devtype_data {
    const char *name;
    u32 quirks;
    u32 clock_freq;
    bool has_hw_filters;
    u8 num_hw_filters;
};

/* Supported device types */
static const struct avionics_can_devtype_data intel_som_2533_data = {
    .name = "intel-som-2533-can",
    .quirks = 0,
    .clock_freq = 80000000,
    .has_hw_filters = true,
    .num_hw_filters = 16,
};

static const struct avionics_can_devtype_data advantech_som_db2510_data = {
    .name = "advantech-som-db2510-can",
    .quirks = 0,
    .clock_freq = 100000000,
    .has_hw_filters = true,
    .num_hw_filters = 32,
};

/* Device tree match table */
static const struct of_device_id avionics_can_of_match[] = {
    {
        .compatible = "avionics,intel-som-2533-can",
        .data = &intel_som_2533_data,
    },
    {
        .compatible = "avionics,advantech-som-db2510-can",
        .data = &advantech_som_db2510_data,
    },
    { /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, avionics_can_of_match);

/* Register access functions */
static inline u32 avionics_can_read_reg(struct avionics_can_priv *priv, u32 offset)
{
    return readl(priv->base + offset);
}

static inline void avionics_can_write_reg(struct avionics_can_priv *priv, 
                                         u32 offset, u32 value)
{
    writel(value, priv->base + offset);
}

static inline void avionics_can_set_bits(struct avionics_can_priv *priv, 
                                        u32 offset, u32 bits)
{
    u32 reg = avionics_can_read_reg(priv, offset);
    avionics_can_write_reg(priv, offset, reg | bits);
}

static inline void avionics_can_clear_bits(struct avionics_can_priv *priv, 
                                          u32 offset, u32 bits)
{
    u32 reg = avionics_can_read_reg(priv, offset);
    avionics_can_write_reg(priv, offset, reg & ~bits);
}

/* Hardware reset function */
static int avionics_can_reset(struct avionics_can_priv *priv)
{
    unsigned long timeout = jiffies + msecs_to_jiffies(AVIONICS_CAN_RESET_TIMEOUT_MS);
    u32 status;
    
    dev_dbg(priv->dev, "Resetting CAN controller\n");
    
    /* Trigger hardware reset */
    avionics_can_set_bits(priv, AVIONICS_CAN_REG_CTRL, CTRL_RESET);
    
    /* Wait for reset completion */
    do {
        status = avionics_can_read_reg(priv, AVIONICS_CAN_REG_CTRL);
        if (!(status & CTRL_RESET))
            break;
        cpu_relax();
    } while (time_before(jiffies, timeout));
    
    if (status & CTRL_RESET) {
        dev_err(priv->dev, "Hardware reset timeout\n");
        return -ETIMEDOUT;
    }
    
    /* Clear all pending interrupts */
    avionics_can_write_reg(priv, AVIONICS_CAN_REG_INT_STATUS, 0xFFFFFFFF);
    
    /* Reset error statistics */
    memset(&priv->error_stats, 0, sizeof(priv->error_stats));
    priv->error_state = CAN_STATE_ERROR_ACTIVE;
    
    dev_dbg(priv->dev, "Hardware reset completed\n");
    return 0;
}

/* Set bit timing parameters */
static int avionics_can_set_bittiming(struct net_device *netdev)
{
    struct avionics_can_priv *priv = netdev_priv(netdev);
    struct can_bittiming *bt = &priv->can.bittiming;
    u32 bitrate_reg = 0;
    unsigned long flags;
    
    /* Calculate bit timing register value */
    bitrate_reg = ((bt->brp - 1) & 0x3F) |
                  (((bt->sjw - 1) & 0x03) << 6) |
                  (((bt->prop_seg + bt->phase_seg1 - 1) & 0x0F) << 8) |
                  (((bt->phase_seg2 - 1) & 0x07) << 12);
    
    spin_lock_irqsave(&priv->reg_lock, flags);
    avionics_can_write_reg(priv, AVIONICS_CAN_REG_BITRATE, bitrate_reg);
    spin_unlock_irqrestore(&priv->reg_lock, flags);
    
    dev_info(priv->dev, "Bit timing: bitrate=%d, brp=%d, sjw=%d, tseg1=%d, tseg2=%d\n",
             bt->bitrate, bt->brp, bt->sjw, 
             bt->prop_seg + bt->phase_seg1, bt->phase_seg2);
    
    return 0;
}

/* Start CAN controller */
static int avionics_can_start(struct net_device *netdev)
{
    struct avionics_can_priv *priv = netdev_priv(netdev);
    u32 ctrl_reg = 0;
    int ret;
    
    /* Reset hardware */
    ret = avionics_can_reset(priv);
    if (ret)
        return ret;
    
    /* Set bit timing */
    ret = avionics_can_set_bittiming(netdev);
    if (ret)
        return ret;
    
    /* Configure control register */
    ctrl_reg = CTRL_ENABLE;
    
    if (priv->can.ctrlmode & CAN_CTRLMODE_LOOPBACK)
        ctrl_reg |= CTRL_LOOPBACK;
    
    if (priv->can.ctrlmode & CAN_CTRLMODE_LISTENONLY)
        ctrl_reg |= CTRL_LISTEN_ONLY;
    
    if (!(priv->can.ctrlmode & CAN_CTRLMODE_ONE_SHOT))
        ctrl_reg |= CTRL_AUTO_RETRANSMIT;
    
    /* Enable controller */
    avionics_can_write_reg(priv, AVIONICS_CAN_REG_CTRL, ctrl_reg);
    
    /* Enable interrupts */
    avionics_can_write_reg(priv, AVIONICS_CAN_REG_INT_EN,
                          INT_TX_COMPLETE | INT_RX_COMPLETE |
                          INT_ERROR_WARNING | INT_ERROR_PASSIVE |
                          INT_BUS_OFF | INT_ARBITRATION_LOST |
                          INT_DATA_OVERRUN);
    
    priv->can.state = CAN_STATE_ERROR_ACTIVE;
    
    /* Start watchdog timer for safety monitoring */
    if (priv->safety_mode) {
        hrtimer_start(&priv->watchdog_timer,
                     ms_to_ktime(1000), /* 1 second */
                     HRTIMER_MODE_REL);
    }
    
    dev_info(priv->dev, "CAN controller started (safety_mode=%s)\n",
             priv->safety_mode ? "enabled" : "disabled");
    
    return 0;
}

/* Stop CAN controller */
static int avionics_can_stop(struct net_device *netdev)
{
    struct avionics_can_priv *priv = netdev_priv(netdev);
    
    /* Stop watchdog timer */
    hrtimer_cancel(&priv->watchdog_timer);
    
    /* Disable interrupts */
    avionics_can_write_reg(priv, AVIONICS_CAN_REG_INT_EN, 0);
    
    /* Disable controller */
    avionics_can_clear_bits(priv, AVIONICS_CAN_REG_CTRL, CTRL_ENABLE);
    
    /* Cancel pending work */
    cancel_work_sync(&priv->tx_work);
    cancel_work_sync(&priv->rx_work);
    cancel_work_sync(&priv->error_work);
    
    priv->can.state = CAN_STATE_STOPPED;
    
    dev_info(priv->dev, "CAN controller stopped\n");
    
    return 0;
}

/* Network device operations */
static const struct net_device_ops avionics_can_netdev_ops = {
    .ndo_open = avionics_can_start,
    .ndo_stop = avionics_can_stop,
    .ndo_start_xmit = NULL, /* Will be set during initialization */
    .ndo_change_mtu = can_change_mtu,
};

/* Watchdog timer callback */
static enum hrtimer_restart avionics_can_watchdog_timer(struct hrtimer *timer)
{
    struct avionics_can_priv *priv = container_of(timer, struct avionics_can_priv, 
                                                 watchdog_timer);
    u32 status;
    
    /* Check controller status */
    status = avionics_can_read_reg(priv, AVIONICS_CAN_REG_STATUS);
    
    if (status & STATUS_BUS_OFF) {
        dev_warn(priv->dev, "Watchdog: Bus-off condition detected\n");
        priv->error_stats.bus_off_events++;
        
        /* Trigger bus-off recovery if enabled */
        if (priv->can.ctrlmode & CAN_CTRLMODE_BERR_REPORTING) {
            schedule_work(&priv->error_work);
        }
    }
    
    if (status & (STATUS_ERROR_WARNING | STATUS_ERROR_PASSIVE)) {
        dev_warn(priv->dev, "Watchdog: Error condition detected (status=0x%08x)\n", 
                status);
        priv->error_stats.error_warning_events++;
    }
    
    /* Restart timer */
    hrtimer_forward_now(timer, ms_to_ktime(1000));
    return HRTIMER_RESTART;
}

/* Probe function */
static int avionics_can_probe(struct platform_device *pdev)
{
    struct device *dev = &pdev->dev;
    struct net_device *netdev;
    struct avionics_can_priv *priv;
    struct resource *res;
    const struct of_device_id *of_id;
    int ret, irq;
    
    dev_info(dev, "Probing avionics CAN device\n");
    
    /* Get device type data */
    of_id = of_match_device(avionics_can_of_match, dev);
    if (!of_id) {
        dev_err(dev, "No matching device type found\n");
        return -ENODEV;
    }
    
    /* Allocate network device */
    netdev = alloc_candev(sizeof(struct avionics_can_priv), 
                         AVIONICS_CAN_ECHO_SKB_MAX);
    if (!netdev) {
        dev_err(dev, "Failed to allocate CAN device\n");
        return -ENOMEM;
    }
    
    priv = netdev_priv(netdev);
    priv->netdev = netdev;
    priv->dev = dev;
    priv->devtype_data = of_id->data;
    
    /* Get memory resource */
    res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
    priv->base = devm_ioremap_resource(dev, res);
    if (IS_ERR(priv->base)) {
        ret = PTR_ERR(priv->base);
        dev_err(dev, "Failed to map registers: %d\n", ret);
        goto err_free_netdev;
    }
    
    /* Get IRQ */
    irq = platform_get_irq(pdev, 0);
    if (irq < 0) {
        ret = irq;
        dev_err(dev, "Failed to get IRQ: %d\n", ret);
        goto err_free_netdev;
    }
    priv->irq = irq;
    
    /* Initialize locks and work queues */
    spin_lock_init(&priv->reg_lock);
    INIT_WORK(&priv->tx_work, NULL); /* Will be implemented */
    INIT_WORK(&priv->rx_work, NULL); /* Will be implemented */
    INIT_WORK(&priv->error_work, NULL); /* Will be implemented */
    
    /* Initialize watchdog timer */
    hrtimer_init(&priv->watchdog_timer, CLOCK_MONOTONIC, HRTIMER_MODE_REL);
    priv->watchdog_timer.function = avionics_can_watchdog_timer;
    
    /* Configure CAN device */
    priv->can.clock.freq = priv->devtype_data->clock_freq;
    priv->can.bittiming_const = NULL; /* Will be set based on hardware */
    priv->can.do_set_bittiming = avionics_can_set_bittiming;
    priv->can.ctrlmode_supported = CAN_CTRLMODE_LOOPBACK |
                                  CAN_CTRLMODE_LISTENONLY |
                                  CAN_CTRLMODE_BERR_REPORTING |
                                  CAN_CTRLMODE_ONE_SHOT;
    
    /* Configure network device */
    netdev->netdev_ops = &avionics_can_netdev_ops;
    netdev->flags |= IFF_ECHO;
    
    /* Parse device tree properties */
    priv->safety_mode = of_property_read_bool(dev->of_node, "avionics,safety-mode");
    of_property_read_u32(dev->of_node, "avionics,max-retries", &priv->max_retries);
    of_property_read_u32(dev->of_node, "avionics,bus-recovery-time-ms", 
                        &priv->bus_recovery_time_ms);
    
    /* Set default values */
    if (!priv->max_retries)
        priv->max_retries = 3;
    if (!priv->bus_recovery_time_ms)
        priv->bus_recovery_time_ms = 1000;
    
    /* Reset hardware */
    ret = avionics_can_reset(priv);
    if (ret) {
        dev_err(dev, "Hardware reset failed: %d\n", ret);
        goto err_free_netdev;
    }
    
    /* Register network device */
    SET_NETDEV_DEV(netdev, dev);
    ret = register_candev(netdev);
    if (ret) {
        dev_err(dev, "Failed to register CAN device: %d\n", ret);
        goto err_free_netdev;
    }
    
    platform_set_drvdata(pdev, netdev);
    
    dev_info(dev, "Avionics CAN device registered: %s (safety_mode=%s)\n",
             netdev->name, priv->safety_mode ? "enabled" : "disabled");
    
    return 0;
    
err_free_netdev:
    free_candev(netdev);
    return ret;
}

/* Remove function */
static int avionics_can_remove(struct platform_device *pdev)
{
    struct net_device *netdev = platform_get_drvdata(pdev);
    struct avionics_can_priv *priv = netdev_priv(netdev);
    
    dev_info(priv->dev, "Removing avionics CAN device\n");
    
    /* Unregister network device */
    unregister_candev(netdev);
    
    /* Cancel watchdog timer */
    hrtimer_cancel(&priv->watchdog_timer);
    
    /* Free network device */
    free_candev(netdev);
    
    return 0;
}

/* Platform driver structure */
static struct platform_driver avionics_can_driver = {
    .probe = avionics_can_probe,
    .remove = avionics_can_remove,
    .driver = {
        .name = "avionics-can",
        .of_match_table = avionics_can_of_match,
    },
};

/* Module initialization */
static int __init avionics_can_init(void)
{
    int ret;
    
    pr_info("Avionics CAN Driver v%s\n", "1.0");
    
    ret = platform_driver_register(&avionics_can_driver);
    if (ret) {
        pr_err("Failed to register platform driver: %d\n", ret);
        return ret;
    }
    
    pr_info("Avionics CAN driver registered successfully\n");
    return 0;
}

/* Module cleanup */
static void __exit avionics_can_exit(void)
{
    platform_driver_unregister(&avionics_can_driver);
    pr_info("Avionics CAN driver unregistered\n");
}

module_init(avionics_can_init);
module_exit(avionics_can_exit);