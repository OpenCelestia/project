#ifndef __AK_IPU_H__
#define __AK_IPU_H__

#define AK_IPU_MAX_QUE 2
#include "ak_thread.h"

typedef enum akIPU_ERROR_E {
    ERROR_IPU_OPEN_FAILURE              = ( MODULE_ID_IPU << 24 ) + 0,
    ERROR_IPU_ALREADY_OPEN              = ( MODULE_ID_IPU << 24 ) + 1,
    ERROR_IPU_NOT_OPENED                = ( MODULE_ID_IPU << 24 ) + 2,
    ERROR_IPU_IPU_FLUSH_CACHE_FAILURE   = ( MODULE_ID_IPU << 24 ) + 3,
    ERROR_IPU_CLOSE_FAILURE             = ( MODULE_ID_IPU << 24 ) + 4,
    ERROR_IPU_MUTEX_INIT_FAILURE        = ( MODULE_ID_IPU << 24 ) + 5,
    ERROR_IPU_MUTEX_CLOSE_FAILURE       = ( MODULE_ID_IPU << 24 ) + 6,
    ERROR_IPU_IOCTL_FAILURE             = ( MODULE_ID_IPU << 24 ) + 7,
    ERROR_IPU_QUEUE_NUM                 = ( MODULE_ID_IPU << 24 ) + 8,
    ERROR_IPU_VALUE_ILLEGAL             = ( MODULE_ID_IPU << 24 ) + 9,
}IPU_ERROR_E;

typedef struct akIPU_ATTR_S                     //IPU设备属性
{
    AK_U32 au32QueSize[AK_IPU_MAX_QUE];         //两个队列的内存大小
    AK_U32 u32RespSize;                         //回执队列内存大小
    AK_U32 u32TransBlendQueSize;                //畸变矫正所需的dma内存大小,通过conf大小进行评估
}IPU_ATTR_S;

typedef enum akIPU_LAYER_E
{
    IPU_LAYER_TMP,
}IPU_LAYER_E;


typedef enum akIPU_BLEND_MODE_E
{
    IPU_BLEND_MODE_NORMAL      = 0x00, //正常
    IPU_BLEND_MODE_LIGHTEN     = 0x01, //变亮
    IPU_BLEND_MODE_DARKEN      = 0x02, //变暗
    IPU_BLEND_MODE_MULTIPLY    = 0x03, //相乘
    IPU_BLEND_MODE_AVERAGE     = 0x04, //平均
    IPU_BLEND_MODE_DIFFERENCE  = 0x05, //差值
    IPU_BLEND_MODE_NEGATION    = 0x06, //反相
    IPU_BLEND_MODE_SCREEN      = 0x07, //滤色
    IPU_BLEND_MODE_EXCLUSION   = 0x08, //排除
    IPU_BLEND_MODE_OVERLAY     = 0x09, //叠加
    IPU_BLEND_MODE_SOFTLIGHT   = 0x0A, //柔光
    IPU_BLEND_MODE_HARDLIGHT   = 0x0B, //强光
    IPU_BLEND_MODE_LINEARDODGE = 0x0C, //线性减淡
    IPU_BLEND_MODE_LINEARBURN  = 0x0D, //线性加深
    IPU_BLEND_MODE_LINEARLIGHT = 0x0E, //线性光
    IPU_BLEND_MODE_PINLIGHT    = 0x0F, //点光
}IPU_BLEND_MODE_E;

typedef enum akIPU_COLOR_FMT_E
{
    IPU_COLOR_FMT_FULLPLANE_GREY  = 0X01, //三个分量分开存放
    IPU_COLOR_FMT_FULLPLANE_RGB   = 0X02,
    IPU_COLOR_FMT_FULLPLANE_YV24  = 0X03,
    IPU_COLOR_FMT_FULLPLANE_YV16  = 0X04,
    IPU_COLOR_FMT_FULLPLANE_YV12  = 0X05, //YUV420P

    IPU_COLOR_FMT_SEMIPLANE_NV24  = 0X10, //Y分量单独存放，UV分量交错存放
    IPU_COLOR_FMT_SEMIPLANE_NV42  = 0X11,
    IPU_COLOR_FMT_SEMIPLANE_NV16  = 0X12,
    IPU_COLOR_FMT_SEMIPLANE_NV61  = 0X13,
    IPU_COLOR_FMT_SEMIPLANE_NV12  = 0X14, //YUV420SP
    IPU_COLOR_FMT_SEMIPLANE_NV21  = 0X15,

    IPU_COLOR_FMT_PACKED_ARGB32   = 0X20, //三个分量全部交错存放
    IPU_COLOR_FMT_PACKED_ABGR32   = 0X21,
    IPU_COLOR_FMT_PACKED_BGRA32   = 0X22,
    IPU_COLOR_FMT_PACKED_RGBA32   = 0X23,
    IPU_COLOR_FMT_PACKED_RGB24    = 0X24,
    IPU_COLOR_FMT_PACKED_BGR24    = 0X25,
    IPU_COLOR_FMT_PACKED_RGB565   = 0X26,
    IPU_COLOR_FMT_PACKED_BGR565   = 0X27,
    IPU_COLOR_FMT_PACKED_RGB555   = 0X28,
    IPU_COLOR_FMT_PACKED_BGR555   = 0X29,

    IPU_COLOR_FMT_PACKED_AYUV     = 0X30,
    IPU_COLOR_FMT_PACKED_AVUY     = 0X31,
    IPU_COLOR_FMT_PACKED_VUYA     = 0X32,
    IPU_COLOR_FMT_PACKED_YUVA     = 0X33,
    IPU_COLOR_FMT_PACKED_YUV      = 0X34,
    IPU_COLOR_FMT_PACKED_VUY      = 0X35,
    IPU_COLOR_FMT_PACKED_IYU2     = 0X36,
    IPU_COLOR_FMT_PACKED_YUYV     = 0X37,
    IPU_COLOR_FMT_PACKED_YVYU     = 0X38,
    IPU_COLOR_FMT_PACKED_UYVY     = 0X39,
    IPU_COLOR_FMT_PACKED_VYUY     = 0X3A,

    IPU_COLOR_FMT_INDEX_1BIT      = 0X60, // input
    IPU_COLOR_FMT_INDEX_2BITS     = 0X61, // input
    IPU_COLOR_FMT_INDEX_4BITS     = 0X62, // input
    IPU_COLOR_FMT_INDEX_8BITS     = 0X63, // input
}IPU_COLOR_FMT_E;

typedef enum akIPU_COLOR_TYPE_E
{
    IPU_COLOR_TYPE_UNKNOWN     = 0,
    IPU_COLOR_TYPE_RGB         = 1,
    IPU_COLOR_TYPE_YUV601_PC   = 2,
    IPU_COLOR_TYPE_YUV601_TV   = 3,
    IPU_COLOR_TYPE_YUV709_PC   = 4,
    IPU_COLOR_TYPE_YUV709_TV   = 5,
    IPU_COLOR_TYPE_YUV2020_PC  = 6,
    IPU_COLOR_TYPE_YUV2020_TV  = 7,
}IPU_COLOR_TYPE_E;

typedef enum akIPU_DITHER_E
{
    IPU_DITHER_NONE   = 0,
    IPU_DITHER_BLUE16 = 1,

}IPU_DITHER_E;

typedef enum akIPU_ALPHA_CHN_E      //图片的Alpha通道选择
{
    IPU_ALPHA_CHN_NONE         = 0, //图像没有Alpha通道或不使用Alpha通道，所有像素的alpha = 255
    IPU_ALPHA_CHN_PACKED       = 1, //使用Packed ARGB中的Alpha通道或调色板中的Alpha通道；其它格式时，所有像素的alpha = 255。
    IPU_ALPHA_CHN_TRANS_IDX    = 2, //使用Transparent Index指定的索引值产生蒙板。
                                    //等于指定索引值的像素的alpha=0，其它索引值的像素的alpha=255；只能在Indexed色彩中使用。
    IPU_ALPHA_CHN_PLANE_1BIT   = 4, //使用Plane 3指示的1bit位图作为蒙板
    IPU_ALPHA_CHN_PLANE_2BIT   = 5, //使用Plane 3指示的2bit位图作为蒙板
    IPU_ALPHA_CHN_PLANE_4BIT   = 6, //使用Plane 3指示的4bit位图作为蒙板
    IPU_ALPHA_CHN_PLANE_8BIT   = 7, //使用Plane 3指示的8bit位图作为蒙板

}IPU_ALPHA_CHN_E;

typedef enum akIPU_DIRECTION_E     //图像预处理的旋转翻转
{
    IPU_DIRECTION_UNCHANGE    = 0,  //0x0  保持原样
    IPU_DIRECTION_FLIP_VER    = 1,  //0x1  垂直翻转
    IPU_DIRECTION_FLIP_HOR    = 2,  //0x2  水平翻转（镜像）
    IPU_DIRECTION_ROTATE_180  = 3,  //0x3  180度顺时针旋转
    IPU_DIRECTION_ROTATE_90   = 4,  //0x4  90度顺时针旋转
    IPU_DIRECTION_ROTATE_270  = 5,  //0x5  270度顺时针旋转

}IPU_DIRECTION_E;

typedef struct akIPU_RECT_S  //操作区域矩形描述区域。
{
    AK_S32 s32X;    //操作区域x坐标。
    AK_S32 s32Y;    //操作区域y坐标。
    AK_U32 u32W;    //操作区域宽度。
    AK_U32 u32H;    //操作区域高度。
}IPU_RECT_S;

typedef struct akIPU_DMA_S                      //IPU分配dma内存的描述结构体
{
    AK_U64 u64PhyAddr;                          //物理地址
    AK_VOID *pvAddr;                            //虚拟地址
    AK_U32 u32Len;                              //内存长度
    AK_U32 u32PhyAddrLow;                       //物理地址低32位,用于畸变矫正,可留空
    AK_U8 u8PhyAddrHigh;                        //物理地址高8位,用于畸变矫正,可留空
    AK_U32 u32W;                                //图层宽度,可留空
    AK_U32 u32H;                                //图层高度,可留空
    IPU_COLOR_FMT_E enColorFmt;                 //图层图像类型,可留空
    AK_U32 u32PlantArrange;                     //是否为yuv bgr排列图层,图层颜色分量排列,可留空
    IPU_DIRECTION_E enDirection;                //源图层的旋转方向,可留空
    AK_VOID *pvExt;                             //图层额外信息,可留空
}IPU_DMA_S;

typedef struct akIPU_CMD_QUEUE_S                //单个指令队列的管理结构体
{
    AK_S32 s32InitFlag;                         // flag record init 初始化标记
    AK_RWLOCK_T rwMutex;                        // rwlock 读写锁
    //AK_S32 s32QueId;                          // 指令队列ID(数组下标暂时屏蔽)
    //AK_U8 u8LoopQue;                          //是否设置环形缓冲(暂时默认配置)
    //AK_U8 u8RespUpateAuto;                    //回执队列是否设置自动覆盖(暂时默认配置)
    AK_VOID *pvCmdStart;                        //指令开始的虚拟地址
    AK_VOID *pvCmdOffset;                       //指令当前写入偏移地址
    AK_U32 u32LenCmd;                           //指令缓存长度
    IPU_DMA_S stIpuAddrCmd;                     //指令队列内存描述结构体
    IPU_DMA_S stIpuAddrResp;                    //回执队列内存描述结构体
    AK_U16 u16CmdId;                            //命令ID
    //AK_U8 u8ImgId;                              //图片ID
}IPU_CMD_QUEUE_S;

typedef enum akIPU_BLEND_OPT_TYPE_E
{
    IPU_OPT_SOLID_COLOR_BLENDING     = 0x30, //混合，前景到混合到实色背景
    IPU_OPT_COLOR_KEY_BLENDING       = 0x31, //混合，范围色彩镂空
    IPU_OPT_SPECIFIED_ALPHA_BLENDING = 0x32, //混合，半透明图层比例混合
    IPU_OPT_SOLID_BG_BLENDING        = 0x33, //混合，前景图与纯色背景混合
    IPU_OPT_SOLID_FG_BLENDING        = 0x34, //混合，纯色前景和背景图混合
    IPU_OPT_GRADIENT_BLENDING        = 0x35, //渐变混合，前景到混合到实色背景
}IPU_BLEND_OPT_TYPE_E;

typedef struct akIPU_SOLID_COLOR_BLEND_ATTR_S
{
    IPU_BLEND_MODE_E enBlendMode;
    AK_U8 u8Opacity;
}IPU_SOLID_COLOR_BLEND_ATTR_S;                  //混合，前景到混合到实色背景

typedef struct akIPU_COLOR_SCOPE_BLEND_ATTR_S
{
    AK_U8 u8OpacityPositive;
    AK_U8 u8OpacityNegative;
    IPU_LAYER_E enRefLayer;
    AK_U32 u32RefColor;
    AK_U8 u8Differ;
}IPU_COLOR_SCOPE_BLEND_ATTR_S;                  //混合，范围色彩镂空

typedef struct akIPU_SPECI_ALPHA_BLEND_ATTR_S
{
    AK_U8 u8gAlphaBg;
    AK_U8 u8gAlphaFg;
}IPU_SPECI_ALPHA_BLEND_ATTR_S;                 //混合，半透明图层比例混合

typedef struct akIPU_SOLID_BG_BLEND_ATTR_S
{
    IPU_BLEND_MODE_E enBlendMode;
    AK_U32 u32ColorBG;
    AK_U8 u8Opacity;
}IPU_SOLID_BG_BLEND_ATTR_S;                    //混合，前景图与纯色背景混合

typedef struct akIPU_SOLID_FG_BLEND_ATTR_S
{
    IPU_BLEND_MODE_E enBlendMode;
    AK_U32 u32ColorFG;
    AK_U8 u8Opacity;
}IPU_SOLID_FG_BLEND_ATTR_S;                    //混合，纯色前景和背景图混合

typedef struct akIPU_GRADIENT_BLEND_ATTR_S
{
    IPU_BLEND_MODE_E enBlendMode;
    AK_U8 au8OpacityPoints[4];//4角渐变alpha值
}IPU_GRADIENT_BLEND_ATTR_S;

typedef struct akIPU_BLEND_OPT_S
{
    IPU_BLEND_OPT_TYPE_E enOpt;
    union
    {
        IPU_SOLID_COLOR_BLEND_ATTR_S stSolidColorBlendAttr; //混合，前景到混合到实色背景
        IPU_COLOR_SCOPE_BLEND_ATTR_S stColorScopeBlendAttr; //混合，范围色彩镂空
        IPU_SPECI_ALPHA_BLEND_ATTR_S stSpeciAlphaBlendAttr; //混合，半透明图层比例混合
        IPU_SOLID_BG_BLEND_ATTR_S stSolidBgBlendAttr;       //混合，前景图与纯色背景混合
        IPU_SOLID_FG_BLEND_ATTR_S stSolidFgBlendAttr;       //混合，纯色前景和背景图混合
        IPU_GRADIENT_BLEND_ATTR_S stGradientBlendAttr;      //渐变混合，前景到混合到实色背景
    };
}IPU_BLEND_OPT_S;

typedef struct akIPU_PLANE_S
{
    AK_U64 u64PhyAddr;   /*图片的基地址。对于不使用的plane，保持该位置为0。
                           如果Plane摆放顺序是垂直翻转的（比如BMP格式），那么这个地址应该指向最后一行的行首。 */
    AK_U8  u8PixStride;  /*图片同行相邻像素的地址偏移量，数字代表了Plane号。
                           这是一个无符号数，可填入范围在1-4，代表1-4个byte。对于不使用的plane，保持该位置为0。 */
    AK_U32 u32PitchLine; /*图片相邻两行的行首像素的地址偏移量，数字代表了Plane号。
                         这是一个有符号数，填入实际数字补码，取值范围[-0x80000, 0x80000)
                         如果Plane摆放顺序是垂直翻转的（比如BMP格式），那么这应该是一个负数。
                         对于不使用的plane，保持该位置为0。*/
}IPU_PLANE_S;

#if 0
typedef struct akIPU_TRANS_BLEND_PICS_ATTR_S
{
    AK_VOID *pvConfData;
    AK_U32 u32ConfLen;
}IPU_TRANS_BLEND_PICS_ATTR_S;
#endif

typedef struct akIPU_SURFACE_S               //输入输出图像图层信息
{
    AK_U32 u32Width;                         //图层宽高
    AK_U32 u32Height;
    IPU_COLOR_FMT_E enColorFmt;              //像素格式 输入的像素格式与输出的像素格式不同时会自动进行图像格式转换
    IPU_COLOR_TYPE_E enColorTypeImage;       //原图颜色标准
    IPU_COLOR_TYPE_E enColorTypeWork;        //Cache内颜色标准
    IPU_ALPHA_CHN_E enAlphaChnChoice;        //Alpha通道选择
    IPU_DIRECTION_E enDirection;             //图像预处理的旋转翻转
    AK_U8 u8ColorPadding;                    //当算法引用图片超界区域时,如何处理.
                                             //0x0 复制边缘 0x1 黑色(必须准确设置Cache Color) 0x2  白色(必须准确设置Cache Color)
    AK_U8 u8AlphaChnInv;                     //对Alpha或者plane3的蒙板取反
    AK_U8 u8AlphaDither;                     //输入的Plane 3的bit数不足8bit时，是否使用抖动
    AK_U8 u8AlphaValue;                      //
    AK_U16 u16PaletteOffset;                 //使用索引色格时，索引值在公共调色板上的偏移量
    AK_U16 u16PaletteTransp;                 //alpha channel为2时，使用这个参数指定一个序号，所有索引值等于该序号的像素被认为是透明像素
    IPU_PLANE_S stPlant[4];                  //plane3可为蒙板数据

    AK_U32 u32Reserve1;                      //保留位1
    AK_U32 u32Reserve2;                      //保留位2
}IPU_SURFACE_S;


/*
 * AK_MPI_IPU_Open - open ipu module.
 * @pstIpuAttr[IN]:  ipu attr
 * return: 0 success, others error code.
 */
AK_S32 AK_MPI_IPU_Open(const IPU_ATTR_S *pstIpuAttr);

/*
 * AK_MPI_IPU_Open - close ipu module.
 * return: 0 success, others error code.
 */
AK_S32 AK_MPI_IPU_Close(AK_VOID);


/*
 * AK_MPI_IPU_StartQue - start queue for ipu process.
 * @s32QueId[IN]:  queue id.
 * return: 0 success, others error code.
 */
AK_S32 AK_MPI_IPU_StartQue( AK_S32 s32QueId );

/*
 * AK_MPI_IPU_EndQue - close queue for ipu process.
 * @s32QueId[IN]:  queue id.
 * return: 0 success, others error code.
 */
AK_S32 AK_MPI_IPU_EndQue( AK_S32 s32QueId, AK_BOOL bSync, AK_BOOL bBlock );

/*
 * AK_MPI_IPU_WaitForDone - close queue for ipu process.
 * @s32QueId[IN]:  queue id.
 * return: 0 success, others error code.
 */
AK_S32 AK_MPI_IPU_WaitForDone(AK_S32 s32QueId, AK_U32 u32Timeout);

/*
 * AK_MPI_IPU_QuickCopy - copy src layer to dst layer.
 * @s32QueId[IN]:  queue id.
 * @pstIpuSurfaceSrc[IN]:  source surface.
 * @pstIpuRectSrc[IN]:  source rect.
 * @pstIpuSurfaceDst[IN]:  destination surface.
 * @pstIpuRectDst[IN]:  destination rect.
 * return: 0 success, others error code.
 */
AK_S32 AK_MPI_IPU_QuickCopy( AK_S32 s32QueId, IPU_SURFACE_S *pstIpuSurfaceSrc, IPU_RECT_S *pstIpuRectSrc,
                                              IPU_SURFACE_S *pstIpuSurfaceDst, IPU_RECT_S *pstIpuRectDst );
/*
 * AK_MPI_IPU_QuickFill - use a color to fill rect of a surface.
 * @s32QueId[IN]:  queue id.
 * @pstDstImg[IN]:  destination surface.
 * @pstDstRect[IN]:  destination rect.
 * @u32FillColor[IN]:  color
 * return: 0 success, others error code.
 */
AK_S32 AK_MPI_IPU_QuickFill(AK_S32 s32QueId, IPU_SURFACE_S *pstDstImg, IPU_RECT_S *pstDstRect, AK_U32 u32FillColor);

/*
 * AK_MPI_IPU_CompositeResize - resize rect of source surface to destination surface.
 * @s32QueId[IN]:  queue id.
 * @pstSrcImg[IN]:  source surface.
 * @pstSrcRect[IN]: source rect.
 * @pstDstImg[IN]:  destination surface.
 * @pstDstRect[IN]:  destination rect.
 * return: 0 success, others error code.
 */
AK_S32 AK_MPI_IPU_CompositeResize(AK_S32 s32QueId, IPU_SURFACE_S *pstSrcImg, IPU_RECT_S *pstSrcRect,
                                  IPU_SURFACE_S *pstDstImg, IPU_RECT_S *pstDstRect );
/*
 * AK_MPI_IPU_Blend - blend opt.
 * @s32QueId[IN]:  queue id.
 * @pstBackGround[IN]: background surface.
 * @pstBackGroundRect[IN]: background rect
 * @pstForeGround[IN]:  foreground surface.
 * @pstForeGroundRect[IN]: foreground rect.
 * @pstDst[IN]: output surface.
 * @pstDstRect[IN]: output rect.
 * @pstBlendOpt[IN]: blend option.
 * return: 0 success, others error code.
 */
AK_S32 AK_MPI_IPU_Blend( AK_S32 s32QueId, IPU_SURFACE_S *pstBackGround, IPU_RECT_S *pstBackGroundRect,
                                          IPU_SURFACE_S *pstForeGround, IPU_RECT_S *pstForeGroundRect,
                                          IPU_SURFACE_S *pstDst,        IPU_RECT_S *pstDstRect,
                                          IPU_BLEND_OPT_S *pstBlendOpt );

/*
 * AK_MPI_IPU_Trans4 - trans4 cmd.
 * @s32QueId[IN]:  queue id.
 * @pstSrcImg[IN]:  source surface.
 * @pstDstImg[IN]: destination surface.
 * @pstIpuDmaBranch[IN]:  branch trans4 cmd
  * return: 0 success, others error code.
 */
AK_S32 AK_MPI_IPU_Trans4( AK_S32 s32QueId, IPU_SURFACE_S *pstSrcImg, IPU_SURFACE_S *pstDstImg,
                          IPU_DMA_S *pstIpuDmaBranch );

/*
 * AK_MPI_IPU_GetVersion - get version
  * return: 0 success, others error code.
 */
const AK_CHAR* AK_MPI_IPU_GetVersion(void);

/*
 * AK_MPI_IPU_GetCmdLen - get cmd len
 * return: 0 success, others error code.
 */
AK_S32 AK_MPI_IPU_GetCmdLen( AK_U8 cmd );
#endif