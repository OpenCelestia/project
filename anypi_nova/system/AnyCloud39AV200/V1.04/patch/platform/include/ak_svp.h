#ifndef __AK_SVP__
#define __AK_SVP__


#include "ak_common.h"
#include "ak_types.h"
#define  CLASSIFY_NUM  80

typedef enum akSVP_ERROR_TYPE_E {
    ERROR_SVP_ALREADY_OPEN         = ( MODULE_ID_SVP << 24 ) + 0,
    ERROR_SVP_HANDLE_ID_ERROR      = ( MODULE_ID_SVP << 24 ) + 1,
    ERROR_SVP_HANDLE_ERROR         = ( MODULE_ID_SVP << 24 ) + 2,
    ERROR_SVP_NOT_CREATE           = ( MODULE_ID_SVP << 24 ) + 3,
    ERROR_SVP_SET_PARAM            = ( MODULE_ID_SVP << 24 ) + 4,
    ERROR_SVP_GET_PARAM            = ( MODULE_ID_SVP << 24 ) + 5,
    ERROR_SVP_ALREADY_INIT         = ( MODULE_ID_SVP << 24 ) + 6,
    ERROR_SVP_ALREADY_DEINIT       = ( MODULE_ID_SVP << 24 ) + 7,
    ERROR_SVP_HANDLE_ID_NOT_CREATE = ( MODULE_ID_SVP << 24 ) + 8,
    ERROR_TYPE_DMA_MALLOC_FAILED   = ( MODULE_ID_SVP << 24 ) + 9,
    ERROR_SVP_GET_DMA_FD_FAILED    = ( MODULE_ID_SVP << 24 ) + 10,
}SVP_ERROR_TYPE_E;

typedef enum akSVP_ENV_MODE_E
{
    AK_SVP_DAY_MODE = 0,        /* 白天模式 */
    AK_SVP_NIGHT_MODE           /* 夜间模式 */
}SVP_ENV_MODE_E;

typedef enum akSVP_TARGET_TYPE_E
{
    AK_SVP_HUMAN_SHAPE = 0,             /* human shape 人形 */
    AK_SVP_HUMAN_FACE,                  /* human face 人脸 */
    AK_SVP_PET,                         /* pet 宠物 */
}SVP_TARGET_TYPE_E;

typedef enum akSVP_MODEL_E
{
    AK_SVP_MODEL_HUMAN_YOLOV5N_640 = 0,      /* 人形检测 0*/
    AK_SVP_MODEL_DETECT,                     /* 检测类 1*/
    AK_SVP_MODEL_AI_ISP,                     /* AI ISP 处理 2*/
    AK_SVP_MODEL_0X0A010001,                 /* 人脸遮挡分类 224*224 6个类别 3*/
    AK_SVP_MODEL_0X0A020003,                 /* 人脸识别 112x112 4*/
    AK_SVP_MODEL_0X0A010007,                 /* 非机动车分类 112x112 5*/
    AK_SVP_MODEL_0X0A010004,                 /* 手势分类 64x64 6*/
    AK_SVP_MODEL_0X0A000005,                 /* 横向人脸检测 320*180 7*/
    AK_SVP_MODEL_0X0A010000,                 /* 活体分类 224x224 8*/
    AK_SVP_MODEL_0X0A010005,                 /* 人脸多角度分类 224x224 9*/
    AK_SVP_MODEL_MAX
}SVP_MODEL_E;

typedef struct akSVP_HD_PARAM_S
{
    AK_S32      s32ClassifyThreshold;
    AK_S32      s32IouThreshold;
}SVP_HD_PARAM_S;

typedef struct akSVP_FAS_PARAM_S
{
    AK_S32 s32ConfidenceThreshold;
}SVP_FAS_PARAM_S;

typedef struct akSVP_FR_PARAM_S
{
    AK_S32 s32CosDistanceThreshold;
}SVP_FR_PARAM_S;

typedef struct akSVP_GESTURE_RE_PARAM_S
{
    AK_S32 s32ConfidenceThreshold;
}SVP_GESTURE_RE_PARAM_S;

typedef struct akSVP_AI_ISP_PARAM_S
{
    AK_S32 s32Reserve;
}SVP_AI_ISP_PARAM_S;

typedef struct akSVP_MODEL_PARAM_S
{
    union
    {
        SVP_HD_PARAM_S  stHdParam;          // human detect         人形检测
        SVP_FAS_PARAM_S stFasParam;         // face Anti-Spoofing   人脸防伪
        SVP_FR_PARAM_S  stFrParam;          // face recognition     人脸识别
        SVP_GESTURE_RE_PARAM_S stGsParam;   // gesture
        SVP_AI_ISP_PARAM_S stAiIspParam;    // AI ISP 处理
    }param;
}SVP_MODEL_PARAM_S;

typedef struct akSVP_MODEL_ATTR_S
{
    SVP_ENV_MODE_E       enEnvMode;         /*环境模式，AK3918AV100不支持*/
    SVP_MODEL_E          enModelType;       /*检测模型类型*/
    SVP_MODEL_PARAM_S    stModelParam;
}SVP_MODEL_ATTR_S;

typedef struct akSVP_CHN_ATTR_S
{
    AK_S32              s32ModelNum;
    SVP_MODEL_ATTR_S    astModelAttr[];
}SVP_CHN_ATTR_S;

typedef AK_S32 (*pfnSvpCusReadFunc)(AK_VOID *pvDstBuf, AK_S32 s32BufLen, const AK_CHAR *pcPath);

typedef enum akSVP_IMG_TYPE_E
{
    AK_SVP_IMG_YUV420SP = 0,                /* YUV420SP，NV12*/
    AK_SVP_IMG_RGB_LI,                      /*RGB line-interlaced format */
    AK_SVP_IMG_RGB_CHW,                     /*RGB RGB_CHW */
    AK_SVP_IMG_RGB_HWC                      /*RGB RGB_HWC */
}SVP_IMG_TYPE_E;

typedef struct akSVP_POS_INFO_S
{
    AK_S32 s32Left;
    AK_S32 s32Top;
    AK_S32 s32Width;
    AK_S32 s32Height;
} SVP_POS_INFO_S;

typedef struct akSVP_IMG_INFO_S
{
    AK_S32              s32ModelIndex;
    SVP_IMG_TYPE_E      enImgType;
    AK_S32              s32Width;
    AK_S32              s32Height;
    SVP_POS_INFO_S      stPosInfo;
    AK_U64              u64PhyAddr;
    AK_VOID             *pvVirAddr;
} SVP_IMG_INFO_S;

typedef struct akSVP_RECT_S         //coordinate values
{
    AK_U32              enLabel;
    AK_U16              u16Left;       //left_top point, horizontal axis
    AK_U16              u16Top;        //left_top point, vertical axis
    AK_U16              u16Right;      //right_bottom point, horizontal axis
    AK_U16              u16Bottom;     //right_bottom point, vertical axis
    AK_U32              u64Score;      //detect score
}SVP_RECT_S;

typedef struct akSVP_HD_RESULT_S
{
    AK_S16      s16ModuleId;
    AK_S16      s16ModuleType;
    AK_S32      s32TotalNum;
    SVP_RECT_S  *pstTargetBoxes;        //coordinate values
}SVP_HD_RESULT_S;

typedef struct akSVP_FAS_RESULT_S
{
    AK_U32 u32Label;
    AK_U32 u32Confidence;
}SVP_FAS_RESULT_S;

typedef struct akSVP_FR_RESULT_S
{
    AK_U32  u32DataLen;          //feature len;
    AK_S16 *pcData;            //feature values;
}SVP_FR_RESULT_S;

typedef struct akSVP_GESTURE_RESULT_S
{
    AK_U32 u32Label;
    AK_U32 u32Confidence;
}SVP_GESTURE_RESULT_S;

typedef struct akFACE_ANGLE_S
{
    AK_U32 u32Label;
    AK_U32 u32Confidence;
}FACE_ANGLE_S;

typedef struct akSVP_FACE_ANGLE_RESULT_S
{
    AK_S32 s32TotalNum;
    FACE_ANGLE_S astFaceAngle[CLASSIFY_NUM];
}SVP_FACE_ANGLE_RESULT_S;

typedef struct akSVP_AI_ISP_RESULT_S
{
    AK_U8 *u8Data;         /*yuv data*/
}SVP_AI_ISP_RESULT_S;


typedef struct akSVP_OUTPUT_S
{
    union{
        SVP_HD_RESULT_S stHdResult;
        SVP_FAS_RESULT_S stFasResult;
        SVP_FR_RESULT_S stFrResult;
        SVP_GESTURE_RESULT_S stGestureResult;
        SVP_FACE_ANGLE_RESULT_S stFaceAngleResult;
        SVP_AI_ISP_RESULT_S stAispResult;
    }result;
    AK_S32  s32ModelType;
    AK_S32  s32ModelIndex;
}SVP_OUTPUT_S;

typedef struct akSVP_BUFFER_S
{
    AK_VOID     *pvData;    // virtual address of the buffer
    AK_U64      u64Pa;      // physical address of the buffer
    AK_U32      u32Size;    // size of the buffer
}SVP_BUFFER_S;

typedef struct akSVP_CONF_INFO_S
{
    union
    {
        AK_CHAR *pcConf;
        SVP_BUFFER_S *pstConfBuf;
    } conf_type;
    AK_S32 s32ConfMode;     // conf load mode, 0: path, 1: buffer
    pfnSvpCusReadFunc pfnReadFunc;
}SVP_CONF_INFO_S;

/**
 * AK_MPI_SVP_GetVersion - get version
 * return: version string
 */
const AK_CHAR* AK_MPI_SVP_GetVersion(AK_VOID);

/**
 * AK_MPI_SVP_CreateChn - setup the svp channel
 * @s32HandleId[IN]   :   the svp handle id
 * @pstAttr[IN]        :   Chn attr to set
 * @pstConfInfo[IN]   :   model file info
 * return AK_SUCCESS is successful,  error code otherwise.
 */
AK_S32 AK_MPI_SVP_CreateChn(AK_S32 s32HandleId, const SVP_CHN_ATTR_S *pstAttr, SVP_CONF_INFO_S *pstConfInfo);

/**
 * AK_MPI_SVP_DestroyChn - close the svp channel
 * @s32HandleId[IN]   :   the svp handle id
 * return AK_SUCCESS is successful,  error code otherwise.
 */
AK_S32 AK_MPI_SVP_DestroyChn(AK_S32 s32HandleId);

/**
 * AK_MPI_SVP_Process - start chn to work
 * @s32HandleId[IN]    :   the svp handle id
 * @pstInput[IN]        :   input tensor
 * @pstOutput[OUT]       :   output tensor
 * return AK_SUCCESS is successful,  error code otherwise.
 */
AK_S32 AK_MPI_SVP_Process(AK_S32 s32HandleId,  SVP_IMG_INFO_S *pstInput,  SVP_OUTPUT_S *pstOutput);

/**
 * AK_MPI_SVP_Release - release the output tensor
 * @pstOutput[IN]       :   output tensor
 * return AK_SUCCESS is successful,  error code otherwise.
 */
AK_S32 AK_MPI_SVP_Release(SVP_OUTPUT_S *pstOutput);

/**
 * AK_MPI_SVP_GetRaram - get model param from the dest chn
 * @s32HandleId[IN]    :   the svp handle id
 * @threshold[OUT]   :   model param info
 * return AK_SUCCESS is successful,  error code otherwise.
 */
AK_S32 AK_MPI_SVP_GetRaram(AK_S32 s32HandleId, SVP_MODEL_PARAM_S *stModelParam);

/**
 * AK_MPI_SVP_SetParam - set model param to the dest chn
 * @s32HandleId[IN]     :   the svp handle id
 * @stModelParam[IN]   :   model param info
 * return AK_SUCCESS is successful,  error code otherwise.
 */
AK_S32 AK_MPI_SVP_SetParam(AK_S32 s32HandleId, SVP_MODEL_PARAM_S stModelParam);

#endif
