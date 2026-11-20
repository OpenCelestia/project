/**
* Copyright (C) 2018 Anyka(Guangzhou) Microelectronics Technology CO.,LTD.
* File Name: ak_cry_sample.c
* Description: This is a simple example to show how the cry module working.
* Notes:Before running please insmod ak_pcm.ko at first.
* History: V1.0.0
*/
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <getopt.h>
#include <errno.h>

#include "ak_common.h"
#include "ak_common_audio.h"
#include "ak_log.h"
#include "ak_mem.h"
#include "ak_thread.h"
#include "ak_audio_effect.h"
#include "effect_Cry.h"
#include "effect_aiCryDetect.h"
#include "ak_npu.h"
#include "ak_ai.h"
#include "effect_LineArraySsl.h"
#include "effect_ssl.h"


#define LEN_HINT         512
#define LEN_OPTION_SHORT 512
#define DEV_STR_LEN      10
#define AK32Q15(x)       ((AK_S32)((x)*(1<<15)))

#define MAIN_CH  0
#define CRY_CH   1
#define LSSL_CH  2

/*detect mode*/
typedef enum akDetectMode
{
    TradDetectMode = 0,// the cpu cry detect
    AIDetectMode = 1   // the npu cry detect
} DetectMode;
/*audio input conf*/
static FILE    *pFp1 = NULL;
static FILE    *pFp2 = NULL;
static FILE    *pFp3 = NULL;
static AK_S32   s32SampleRate = 16000;       //sample rate 
static AK_S32   s32SaveTime = 20000;         // set save time(ms)
static AK_CHAR *spchPcmPath = "/mnt/";        // set save path
static AK_S32   s32SoundMode = AUDIO_SOUND_MODE_MONO;
static AK_S32   s32AiDevId = DEV_ADC;
//static AK_S32   s32AiChnId = 0;
static AK_S32   s32FrameInterval = 32;
static AK_CHAR *spchConfFile =  "/etc/config/audio_config.ini";// config path
static AK_CHAR *spchConfSection = "def_near";        // audio input config section
/*cry detect conf*/
static AK_CHAR *spchConfSectionCry = "ai_cry_1";     // cry config section
static AK_S32 	s32EffectUserIdCry = 5;      // 从[0,AUDIO_EFFECT_USER_MAX_NUM - 1]中任意选取, 但不能和其他已在使用的id冲突。
static AK_S32 s32CryDetectMode = AIDetectMode;
static AK_S32 	s32EffectUserIdSsl = 2; 
static AK_CHAR *spchConfSectionSSL = "def_lssl"; 

/* ***********************************
    ***********************************
    *
    use this sample
    must follow this:
    1. make sure the driver is insmode;
    2. mount the T card;
    3. the file path is exit;
    4. make sure npu driver has insmode
    *
    ***********************************
    ***********************************
*/

    /*help print*/
static const AK_CHAR ac_option_hint[  ][ LEN_HINT ] = {
    "	打印帮助信息" ,
    "	采集时间，单位：秒" ,
    "	采样率[8000 16000]" ,
    "	文件保存路径" ,
    "	设备类型,0:DEV_ADC,1:DEV_PDM,2:DEV_I2S0_AI" ,
    "   音频配置文件全路径" ,
    "   音频配置文件section name def_near:用于ai,如果是双麦可用two_array_near; def_far:用于ao" ,
    "   cry 音频配置文件section name ai_cry_1:基于NPU 方式的哭声检测,目前只支持16K采样率; cry_1:基于CPU 方式的哭声检测" ,
    "	0:纯软件算法方式检测哭声,1:NPU方式检测哭声,目前只支持16K采样率",
    ""
};

    /*option param with short option*/
static struct option option_long[ ] = {
    { "help"          , no_argument       , NULL , 'h' } , //"       打印帮助信息" ,
    { "second"        , required_argument , NULL , 't' } , //"[SEC]  采集时间" ,
    { "sample-rate"   , required_argument , NULL , 's' } , //"[NUM]  采样率[8000 16000 32000 44100 48000]" ,
    { "path"          , required_argument , NULL , 'p' } , //"[PATH] 文件保存路径" ,
    { "device-type"        , required_argument , NULL , 'd' } , //"[NUM] 设备类型，0:DEV_ADC,1:DEV_PDM,2:DEV_I2S0_AI" ,
    { "config-file"        , required_argument , NULL , 'f' } , //"[PATH] 配置文件全路径" ,
    { "ai-config-section"     , required_argument , NULL , 'e' } , //"[STRING] 音频输入模块配置文件section" ,
    { "cry-config-section"     , required_argument , NULL , 'c' } , //"[STRING] cry 配置文件section" ,
    { "detect-mode"    , required_argument , NULL , 'm' } , //"[NUM] 检测算法方式" ,
    {0, 0, 0, 0}
};

/**
 * HelpHint - help note
 * @pc_prog_name[IN]: help parameter
 * notes:
 */
static AK_S32 HelpHint(AK_CHAR *pc_prog_name)
{
    AK_S32 i;

    printf( "version: \r\n  %s \n\n", AK_MPI_AI_GetVersion());
    printf( "usage: \r\n  %s  [options] <value>\n\n", pc_prog_name);
    printf( "options: \r\n");
    for (i = 0; i < sizeof(option_long) / sizeof(struct option) - 1; i ++) {
        printf("  -%c,--%-16s\t%s \n" , option_long[ i ].val , option_long[ i ].name , ac_option_hint[ i ]);
    }
    printf( "\nexample: \r\n"
        " %s -s 16000 -p /mnt/ -t 20 -d 0 -f /etc/config/audio_config.ini \
-e def_near -m 1 -c ai_cry_1\n", pc_prog_name);
    printf("\n\n");
    return 0;
}

/**
 * ps8GetOptionShort - get option short param
 * @p_option[IN]: option 
 * @i_num_option[IN]: option number
 * @pc_option_short[OUT]: option short param
 * @i_len_option[IN]: option len
 * notes:
 */
static AK_CHAR *ps8GetOptionShort(struct option *p_option, AK_S32 i_num_option, AK_CHAR *pc_option_short,
                        AK_S32 i_len_option)
{
    AK_S32 i;
    AK_S32 i_offset = 0;
    AK_CHAR c_option;

    for (i = 0 ; i < i_num_option ; i ++) {
        c_option = p_option[i].val;
        switch (p_option[i].has_arg) {
        case no_argument:
            i_offset += snprintf( pc_option_short + i_offset , i_len_option - i_offset , "%c" , c_option );
            break;
        case required_argument:
            i_offset += snprintf( pc_option_short + i_offset , i_len_option - i_offset , "%c:" , c_option );
            break;
        case optional_argument:
            i_offset += snprintf( pc_option_short + i_offset , i_len_option - i_offset , "%c::" , c_option );
            break;
        }
    }
    return pc_option_short;
}

/**
 * ParseOption - parse option
 * notes:
 */
static AK_S32 ParseOption(AK_S32 argc, AK_CHAR **argv)
{
    AK_S32 i_option;
    AK_CHAR ac_option_short[LEN_OPTION_SHORT];
    AK_S32 i_array_num = sizeof(option_long) / sizeof(struct option) ;
    AK_CHAR c_flag = 1;

    if (argc < 4 && argc != 1) {
        HelpHint(argv[0]);
        c_flag = 0;
        goto parse_option_end;
    }

    ps8GetOptionShort(option_long, i_array_num , ac_option_short , LEN_OPTION_SHORT);
    while ((i_option = getopt_long(argc , argv , ac_option_short , option_long , NULL)) > 0) {
        switch (i_option) {
        case 'h' :                                                      //help
            HelpHint(argv[0]);
            c_flag = 0;
            goto parse_option_end;
        case 't' :                                                     //second
            s32SaveTime = atoi(optarg) * 1000 ;
            break;
        case 's' :                                                     //sample-rate
            s32SampleRate = atoi(optarg);
            break;
        case 'p' :                                                    //path
            spchPcmPath = optarg;
            break;
        case 'd' :                                                   //device type
            if (0 == atoi(optarg)) {
                s32AiDevId = DEV_ADC;
            } else if (1 == atoi(optarg)) {
                s32AiDevId = DEV_PDM;
            } else if (2 == atoi(optarg)) {
                s32AiDevId = DEV_I2S0_AI;
            }
            break;
        case 'f' :                                                          // config path
            spchConfFile = optarg;
            break;
        case 'e' :                                                         // audio input config section
            spchConfSection = optarg;
            break;
        case 'c' :                                                         // cry config section
            spchConfSectionCry = optarg;
            break;
        case 'm':
            s32CryDetectMode = atoi(optarg);                              //cry dedtect mode
            break;
        default:
            HelpHint(argv[0]);
            c_flag = 0;
            goto parse_option_end;
        }
    }
parse_option_end:
    return c_flag;
}

/**
 * PrintPlayingDot - print dot when playing
 * notes: print one dot for 10 seconds
 */
static AK_VOID PrintPlayingDot(AK_VOID)
{
    static AK_U8 u8FirstFlag = 1;
    static TIME_VAL_S stCurTime;
    static TIME_VAL_S stPrintTime;

    if (u8FirstFlag) {
        u8FirstFlag = 0;
        AK_BASE_GetOstime(&stCurTime);
        AK_BASE_GetOstime(&stPrintTime);
        AK_BASE_PrintNormal(MODULE_ID_APP, "\n.");
    }

    /* get time */
    AK_BASE_GetOstime(&stCurTime);
    if (AK_BASE_DiffMsTime(&stCurTime, &stPrintTime) >= 10000) {
        AK_BASE_GetOstime(&stPrintTime);
        AK_BASE_PrintNormal(MODULE_ID_APP, ".\n");
    }
}


/*
 * OpenPcmFile: open pcm file.
 * s32SampleRate[IN]: audio input sample rate.
 * s32SoundMode[IN]: audio input channle number.
 * path[IN]: pointer to the path which will be checking.
 * pFp[OUT]: pointer of opened pcm file.
 * s32SaveTime[IN]: audio input save time.
 * s32AiDevId[IN]: audio input device id, see enum ak_audio_ai_dev_id.
 * return: 0 is success, -1 is error.
 */
static AK_S32 OpenPcmFile(AK_S32 s32SampleRate, AK_S32 s32SoundMode, const AK_CHAR *path, FILE **pFp, \
    AK_S32 s32SaveTime, AK_S32 s32AiDevId)
{
    struct stat s = {0};
    if (stat(path, &s) != 0) {
        printf("stat error. path:%s, errno:%d\n", path, errno);
        return -1;
    }

    if (S_ISDIR(s.st_mode) == 0) {
        printf("path is not dir. path:%s\n", path);
        return -1;
    }

    DATE_S stDate;
    AK_BASE_GetLocalDate(&stDate);
    AK_CHAR achTimeStr[20] = {0};
    AK_BASE_DateToString(&stDate, achTimeStr);
    AK_CHAR achFilePath[255] = {0};
    AK_CHAR achDev[DEV_STR_LEN] = {0};

    if (DEV_ADC == s32AiDevId) {
        strncpy(achDev, "ADC", DEV_STR_LEN);
    } else if (DEV_PDM == s32AiDevId) {
        strncpy(achDev, "PDM", DEV_STR_LEN);
    } else if (DEV_I2S0_AI== s32AiDevId) {
        strncpy(achDev, "I2S0", DEV_STR_LEN);
    } else if (DEV_I2S1_AI == s32AiDevId) {
        strncpy(achDev, "I2S1", DEV_STR_LEN);
    }

    sprintf(achFilePath, "%s/%s_%d_%d_%d_%s.pcm", path, achTimeStr,
            s32SampleRate, s32SoundMode, s32SaveTime, achDev);

    /* open file */
    *pFp = fopen(achFilePath, "wb");
    if (NULL == *pFp) {
        AK_BASE_PrintNormal(MODULE_ID_APP, "open pcm file: %s error\n", achFilePath);
        return -1;
    } else {
        AK_BASE_PrintNormal(MODULE_ID_APP, "open pcm file: %s OK\n", achFilePath);
        return 0;
    }
}


/*
 * ClosePcmFile: close pcm file.
 * pFp[IN]: pointer of opened pcm file.
 * return: AK_VOID.
 */
static AK_VOID ClosePcmFile(FILE *pFp)
{
    if (pFp) {
        fclose(pFp);
        pFp = NULL;
    }
}

/**
 * InitAi - open audio input, set nr, set agc, set gain, set DigitalGain
 * notes:
 */
static AK_S32 InitAi(AK_VOID)
{
    AK_S32 s32Ret = 0;
    AUDIO_IN_PARAM_S stAiParam = {0};
    stAiParam.enSampleBits = 16;
    stAiParam.enSampleRate = s32SampleRate;
    stAiParam.enSoundMode = s32SoundMode;
    stAiParam.u32SrcCnt = 1;  
    stAiParam.u32ChnCnt = 3;  

    if (AK_MPI_AI_SetPubAttr(s32AiDevId, &stAiParam)) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP,"AK_MPI_AI_SetPubAttr failed \n");
        return AK_FAILED;
    }
    if (AK_MPI_AI_Enable(s32AiDevId)) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "AK_MPI_AI_Enable failed\n");
        return AK_FAILED;
    }

    AK_S32  s32FrameLen = 0;
    AK_MPI_AI_GetFrmLen(s32AiDevId, MAIN_CH, &s32FrameLen);// use default frame length
    s32FrameInterval = AudioLenToInterval(s32SampleRate, AK_AUDIO_SMPLE_BIT_16,
                                          s32SoundMode, s32FrameLen);
    /*load conf use to set audio affect param*/
    s32Ret = AK_MPI_AI_LoadConf(s32AiDevId, MAIN_CH, spchConfFile, "two_array_near");
    if (s32Ret) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "AK_MPI_AI_LoadConf failed\n");
        return AK_FAILED;
    }

    s32Ret = AK_MPI_AI_LoadConf(s32AiDevId, CRY_CH, spchConfFile, "config_effect_default_near");
    if (s32Ret) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "AK_MPI_AI_LoadConf failed\n");
        return AK_FAILED;
    }

    s32Ret = AK_MPI_AI_LoadConf(s32AiDevId, LSSL_CH, spchConfFile, "config_effect_lssl_near");
    if (s32Ret) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "AK_MPI_AI_LoadConf failed\n");
        return AK_FAILED;
    }
    /*enable chn of audio input*/
    s32Ret = AK_MPI_AI_EnableChn(s32AiDevId, MAIN_CH);
    if (s32Ret) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "AK_MPI_AI_EnableChn failed\n");
        return AK_FAILED;
    }

    s32Ret = AK_MPI_AI_EnableChn(s32AiDevId, CRY_CH);
    if (s32Ret) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "AK_MPI_AI_EnableChn failed\n");
        return AK_FAILED;
    }

    s32Ret = AK_MPI_AI_EnableChn(s32AiDevId, LSSL_CH);
    if (s32Ret) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "AK_MPI_AI_EnableChn failed\n");
        return AK_FAILED;
    }

    return AK_SUCCESS;
}

/**
 * InitCry - init Cry parameter
 * notes:
 */
static AK_S32 InitCry(AK_VOID)
{
    AK_S32 s32Ret = AK_SUCCESS;
    AUDIO_DATA_ATTR_S   stAudioDataAttrCry = {s32SampleRate, AK_AUDIO_SMPLE_BIT_16, AUDIO_SOUND_MODE_MONO};

    if (TradDetectMode == s32CryDetectMode) { // CPU
        AUDIO_EFFECT_TYPE_E    enEffectTypeCry = AK_AUDIO_CRY;
        AUDIO_EFFECT_REG_S     stAudioEffectCry = {AK_AUDIO_CRY, Effect_CRY_Open,
                                    Effect_CRY_Close, Effect_CRY_Process, Effect_CRY_SetAttr};
        AK_BASE_PrintNoticeEx(MODULE_ID_APP, "Notice: Detect Cry use CPU\n");

        s32Ret = AK_MPI_AUDIO_EFFECT_Register(&stAudioEffectCry);
        if (s32Ret) {
            AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR: AK_MPI_AUDIO_EFFECT_Register Cry s32Ret = %d\n", s32Ret);
            return s32Ret;
        }

        s32Ret = AK_MPI_AUDIO_EFFECT_Init(
            s32EffectUserIdCry,
            &stAudioDataAttrCry,
            enEffectTypeCry,
            spchConfFile,
            spchConfSectionCry);

        if (s32Ret) {
            AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR: AK_MPI_AUDIO_EFFECT_Init Cry s32Ret = %d\n", s32Ret);
            return s32Ret;
        }
    } else if (AIDetectMode == s32CryDetectMode) { // NPU
        AUDIO_EFFECT_TYPE_E     enEffectTypeAiCry = AK_AUDIO_AI_CRY;
        AUDIO_EFFECT_REG_S      stAudioEffectAiCry = {  AK_AUDIO_AI_CRY, Effect_AICRYDET_Open, Effect_AICRYDET_Close,
                                                        Effect_AICRYDET_Process, Effect_AICRYDET_SetAttr };
        AK_BASE_PrintNoticeEx(MODULE_ID_APP, "Notice: Detect Cry use NPU\n");
        /*init npu*/
        s32Ret = AK_MPI_NPU_Init();
        if (s32Ret) {
            AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR: AK_MPI_NPU_Init,  s32Ret = %d\n", s32Ret);
            return AK_FAILED;
        }

        s32Ret = AK_MPI_AUDIO_EFFECT_Register(&stAudioEffectAiCry);
        if (s32Ret) {
            AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR: AK_MPI_AUDIO_EFFECT_Register AiCry s32Ret = %d\n", s32Ret);
            return s32Ret;
        }

        s32Ret = AK_MPI_AUDIO_EFFECT_Init(
            s32EffectUserIdCry,
            &stAudioDataAttrCry,
            enEffectTypeAiCry,
            spchConfFile,
            spchConfSectionCry);

        if (s32Ret) {
            AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR: AK_MPI_AUDIO_EFFECT_Init AiCry s32Ret = %d\n", s32Ret);
            return s32Ret;
        }
    } else {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR: Not support s32CryDetectMode = %d\n", s32CryDetectMode);
        return AK_FAILED;
    }

    return AK_SUCCESS;
}


/**
 * DestroyCry - close Cry
 * notes:
 */
static AK_VOID DestroyCry(AK_VOID)
{
    AK_S32 s32Ret = AK_MPI_AUDIO_EFFECT_DeInit(s32EffectUserIdCry);
    if (s32Ret) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR: AK_MPI_AUDIO_EFFECT_DeInit, Cry s32Ret = %d\n", s32Ret);
    }
    if (AIDetectMode == s32CryDetectMode) {
         AK_MPI_NPU_Deinit();
    }
}

/**
 * DestroyAi - close audio input
 * notes:
 */
static AK_VOID DestroyAi(AK_VOID)
{
    if (-1 != s32AiDevId) {
        /* audio input close */
        AK_MPI_AI_DisableChn(s32AiDevId, MAIN_CH);
        AK_MPI_AI_DisableChn(s32AiDevId, CRY_CH);
        AK_MPI_AI_DisableChn(s32AiDevId, LSSL_CH);
        AK_MPI_AI_Disable(s32AiDevId);
        s32AiDevId = -1;
    }
}

/**
 * InitSslByConf - Init Ssl parameter by conf
 * notes:
 */
static AK_S32 InitSsl(AK_VOID)
{
    AK_S32 s32Ret = AK_SUCCESS;
    AUDIO_DATA_ATTR_S       stAudioDataAttrSsl = {s32SampleRate, AK_AUDIO_SMPLE_BIT_16, s32SoundMode};
    AUDIO_EFFECT_TYPE_E     enEffectTypeSsl = AK_AUDIO_LSSL;
    AUDIO_EFFECT_REG_S      stAudioEffectSsl = {AK_AUDIO_LSSL, Effect_LineArraySSL_Open, \
    Effect_LineArraySSL_Close, Effect_LineArraySSL_Process, Effect_LineArraySSL_SetAttr};

    /*register ssl effect */
    s32Ret = AK_MPI_AUDIO_EFFECT_Register(&stAudioEffectSsl);
    if(s32Ret){
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR: AK_MPI_AUDIO_EFFECT_Register Ssl s32Ret = %d\n", s32Ret);
        return s32Ret;
    }

    s32Ret = AK_MPI_AUDIO_EFFECT_Init(
        s32EffectUserIdSsl,
        &stAudioDataAttrSsl,
        enEffectTypeSsl,
        spchConfFile,
        spchConfSectionSSL );

    if(s32Ret){
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR: AK_MPI_AUDIO_EFFECT_Init Ssl s32Ret = %d\n", s32Ret);
        return s32Ret;
    }

    return AK_SUCCESS;
}


/**
 * DestroySsl - close Ssl
 * notes:
 */
static AK_VOID DestroySsl(AK_VOID)
{
    AK_S32 s32Ret = AK_MPI_AUDIO_EFFECT_DeInit(s32EffectUserIdSsl);
    if (s32Ret) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR: AK_MPI_AUDIO_EFFECT_DeInit, Ssl s32Ret = %d\n", s32Ret);
    }
}

static AK_S32 ShowAICryResult(AUDIO_EFFECT_RESULT_S *pstEffectResult)
{
    AK_S32 s32Index = 0;
    AUDIO_AICRY_RESULT_LIST_S *pList = pstEffectResult->unEffectResult.pstDetResult;
    if (pList) {
        while(pList){
            AK_BASE_PrintNoticeEx(MODULE_ID_APP, "s32Index = %d, u64TimeOffset = %ld\n",\
                s32Index, pList->stResult->u64TimeOffset);
            pList = (AUDIO_AICRY_RESULT_LIST_S *)(pList->next);
            s32Index ++;
        }
        printf("\n");
    }
}

static AK_S32 ShowCryResult(AUDIO_EFFECT_RESULT_S *pstEffectResult)
{
    AK_S32 s32Index = 0;
    AUDIO_CRY_RESULT_LIST_S *pList = pstEffectResult->unEffectResult.pstDetResult;
    if (pList) {
        while (pList) {
            AK_BASE_PrintNoticeEx(MODULE_ID_APP, "s32Index = %d, u64TimeOffset = %ld\n",\
                s32Index, pList->stResult->u64TimeOffset);
            pList = (AUDIO_CRY_RESULT_LIST_S *)(pList->next);
            s32Index ++;
        }
        printf("\n");
    }
}

/*
 * AiCaptureLoop: loop to get and release pcm data, between get and release,
 *                  here we just save the frame to file, on your platform,
 *                  you can rewrite the save_function with your code.
 */
static AK_VOID* AiGetFrameLoopAndCryDetect(AK_VOID *arg)
{
    /*set thread name*/
    AK_BASE_ThreadSetName("[cry sample]attachment");
    AK_U32  u32StartTs = 0;// use to save capture start time
    AK_U32  u32EndTs = 0;    // the last frame time
    FRAME_S stFrame = {0};
    AK_S32  s32Ret = AK_FAILED;
    AK_S32  s32SleepTime = s32FrameInterval == 0 ? 10: (s32FrameInterval / 2);
    AK_S32  s32TimeOut = 1000;  //timeout use to block
    AK_S32  sReserved = 0;      // not to use
    AUDIO_EFFECT_RESULT_S stEffectResult = {0};
    if (1 == s32CryDetectMode) {
        stEffectResult.u32EffectType = AK_AUDIO_AI_CRY;
        stEffectResult.u32UnionBufSize = sizeof(AUDIO_AICRY_RESULT_S);
    } else {
        stEffectResult.u32EffectType = AK_AUDIO_CRY;
        stEffectResult.u32UnionBufSize = sizeof(AUDIO_CRY_RESULT_S);
    }
    AK_BASE_PrintNormalEx(MODULE_ID_APP, "s32SleepTime=%d\n", s32SleepTime);
    AK_BASE_PrintNormal(MODULE_ID_APP, "*** get frame start ***\n");
    while (1) {
        /* get the pcm data frame */
        s32Ret = AK_MPI_AI_GetFrame(s32AiDevId, CRY_CH, &stFrame,  s32TimeOut, sReserved);
        if (s32Ret) {
            if (ERROR_AI_NO_DATA == s32Ret) {
                AK_BASE_SleepMs(s32SleepTime);
                continue;
            } else {
                break;
            }
        }
        PrintPlayingDot();
        if (!stFrame.pu8Data || stFrame.u32Len <= 0) {
            AK_BASE_SleepMs(s32SleepTime);
            continue;
        }
        /*get frame and write it to save file */
        if (NULL != pFp3) {
            if (fwrite(stFrame.pu8Data, stFrame.u32Len, 1, pFp3) < 0) {
        s32Ret = AK_MPI_AI_GetFrame(s32AiDevId, CRY_CH, &stFrame,  s32TimeOut, sReserved);
                AK_MPI_AI_ReleaseFrame(s32AiDevId, CRY_CH, &stFrame, sReserved);
                AK_BASE_PrintNormal(MODULE_ID_APP, "write file error.\n");
                break;
            }
        }
        /* detect Cry */
        s32Ret = AK_MPI_AUDIO_EFFECT_Process( s32EffectUserIdCry, stFrame.pu8Data, stFrame.u32Len, &stEffectResult);
        if (s32Ret != AK_SUCCESS) {
            AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR:  Cry Detect Error: s32Ret = %d\n", s32Ret);
            AK_MPI_AI_ReleaseFrame(s32AiDevId, CRY_CH, &stFrame, sReserved);
            break;
        } else {
            if (1 == s32CryDetectMode) {
                ShowAICryResult(&stEffectResult);
            } else {
                ShowCryResult(&stEffectResult);
            }
        }
        /* save the begin time */
        if (0 == u32StartTs) {
            u32StartTs = stFrame.u64Ts;
            u32EndTs = stFrame.u64Ts;
        }
        u32EndTs = stFrame.u64Ts;
        /*release frame had capture*/
        AK_MPI_AI_ReleaseFrame(s32AiDevId, CRY_CH, &stFrame, sReserved);
        /* time is up */
        if ((u32EndTs - u32StartTs) >= s32SaveTime) {
            AK_BASE_PrintNormal(MODULE_ID_APP, "*** timp is up, start_ts = %lld, \
             end_ts = %lld, s32SaveTime = %d ***\n\n",
            u32StartTs, u32EndTs, s32SaveTime);
            break;
        }
    }

    AK_BASE_PrintNormalEx(MODULE_ID_APP, "*** capture finish ***\n\n");
    AK_BASE_ThreadExit();
    return NULL;
}

/*
 * AiCaptureLoop: loop to get and release pcm data, between get and release,
 *                  here we just save the frame to file, on your platform,
 *                  you can rewrite the save_function with your code.
 */
static AK_VOID* AiGetFrameLoopAndSsl(AK_VOID *arg)
{
    /*set thread name*/
    AK_BASE_ThreadSetName("[ssl sample]attachment");
    AK_U32  u32StartTs = 0;// use to save capture start time
    AK_U32  u32EndTs = 0;    // the last frame time
    FRAME_S stFrame = {0};
    AK_S32  s32Ret = AK_FAILED;
    AK_S32  s32SleepTime = s32FrameInterval == 0 ? 10: (s32FrameInterval / 2);
    AK_S32  s32TimeOut = 1000;  //timeout use to block
    AK_S32  sReserved = 0;      // not to use
    AUDIO_EFFECT_RESULT_S stEffectResult = {0};
    stEffectResult.u32EffectType = AK_AUDIO_LSSL;//必填项
    stEffectResult.u32UnionBufSize = sizeof(AUDIO_SSL_RESULT_S);//必填项
    AK_S32 curAzimuth = 0;
    AK_BASE_PrintNormalEx(MODULE_ID_APP, "s32SleepTime=%d\n", s32SleepTime);
    AK_BASE_PrintNormal(MODULE_ID_APP, "*** get frame start ***\n");
    while (1) {
        /* get the pcm data frame */
        s32Ret = AK_MPI_AI_GetFrame(s32AiDevId, LSSL_CH, &stFrame,  s32TimeOut, sReserved);
        if (s32Ret) {
            if (ERROR_AI_NO_DATA == s32Ret) {
                AK_BASE_SleepMs(s32SleepTime);
                continue;
            } else {
                break;
            }
        }
        //AK_BASE_PrintNormal(MODULE_ID_APP, "*** len=%d ***\n", stFrame.u32Len);
        if (!stFrame.pu8Data || stFrame.u32Len <= 0) {
            AK_BASE_SleepMs(s32SleepTime);
            continue;
        }
        /*get frame and write it to save file */
        if (NULL != pFp2) {
            if(fwrite(stFrame.pu8Data, stFrame.u32Len, 1, pFp2) < 0) {
                AK_MPI_AI_ReleaseFrame(s32AiDevId, LSSL_CH, &stFrame, sReserved);
                AK_BASE_PrintNormal(MODULE_ID_APP, "write file error.\n");
                break;
            }
        }

        /* detect ssl */
        s32Ret = AK_MPI_AUDIO_EFFECT_Process(s32EffectUserIdSsl, stFrame.pu8Data, stFrame.u32Len, &stEffectResult);
        if (s32Ret != AK_SUCCESS) {
            AK_BASE_PrintErrorEx(MODULE_ID_APP, "ERROR:  Ssl Detect Error: s32Ret = %d\n", s32Ret);
            break;
        } else {
            AUDIO_SSL_RESULT_LIST_S *pResult = stEffectResult.unEffectResult.pstDetResult;
            if (pResult) {
                curAzimuth = pResult->stResult->pastSndSrcDir->azimuth * 90 / (1<<15);
                AK_BASE_PrintNormal(MODULE_ID_APP, "##########curAzimuth = %d.#######\n",curAzimuth);
            } 
        }
        /* save the begin time */
        if (0 == u32StartTs) {
            u32StartTs = stFrame.u64Ts;
            u32EndTs = stFrame.u64Ts;
        }
        u32EndTs = stFrame.u64Ts;
        /*release frame had capture*/
        AK_MPI_AI_ReleaseFrame(s32AiDevId, LSSL_CH, &stFrame, sReserved);

        /* time is up */
        if ((u32EndTs - u32StartTs) >= s32SaveTime) {
            AK_BASE_PrintNormal(MODULE_ID_APP, "*** timp is up, start_ts = %lld, \
             end_ts = %lld, s32SaveTime = %d ***\n\n",
            u32StartTs, u32EndTs, s32SaveTime);
            break;
        }
    }

    AK_BASE_PrintNormalEx(MODULE_ID_APP, "*** capture finish ***\n\n");
    AK_BASE_ThreadExit();
    return NULL;
}

/*
 * AiCaptureLoop: loop to get and release pcm data, between get and release,
 *                  here we just save the frame to file, on your platform,
 *                  you can rewrite the save_function with your code.
 */
static AK_VOID* AiGetFrameLoop(AK_VOID *arg)
{
    /*set thread name*/
    AK_BASE_ThreadSetName("[ai sample]attachment");
    AK_U32  u32StartTs = 0;// use to save capture start time
    AK_U32  u32EndTs = 0;    // the last frame time
    FRAME_S stFrame = {0};
    AK_S32  s32Ret = AK_FAILED;
    AK_S32  s32SleepTime = s32FrameInterval == 0 ? 10: (s32FrameInterval / 2);
    AK_S32  s32TimeOut = 1000;  //timeout use to block
    AK_S32  sReserved = 0;      // not to use
    AK_BASE_PrintNormalEx(MODULE_ID_APP, "s32SleepTime=%d\n", s32SleepTime);
    AK_BASE_PrintNormal(MODULE_ID_APP, "*** get frame start ***\n");
    while (1) {
        /* get the pcm data frame */
        s32Ret = AK_MPI_AI_GetFrame(s32AiDevId, MAIN_CH, &stFrame,  s32TimeOut, sReserved);
        if (s32Ret) {
            if (ERROR_AI_NO_DATA == s32Ret) {
                AK_BASE_SleepMs(s32SleepTime);
                continue;
            } else {
                break;
            }
        }
        //AK_BASE_PrintNormal(MODULE_ID_APP, "------*** len=%d ***\n", stFrame.u32Len);
        if (!stFrame.pu8Data || stFrame.u32Len <= 0) {
            AK_BASE_SleepMs(s32SleepTime);
            continue;
        }
        /*get frame and write it to save file */
        if (NULL != pFp1) {
            if(fwrite(stFrame.pu8Data, stFrame.u32Len, 1, pFp1) < 0) {
                AK_MPI_AI_ReleaseFrame(s32AiDevId, MAIN_CH, &stFrame, sReserved);
                AK_BASE_PrintNormal(MODULE_ID_APP, "write file error.\n");
                break;
            }
        }

        /* save the begin time */
        if (0 == u32StartTs) {
            u32StartTs = stFrame.u64Ts;
            u32EndTs = stFrame.u64Ts;
        }
        u32EndTs = stFrame.u64Ts;

        /*release frame had capture*/
        AK_MPI_AI_ReleaseFrame(s32AiDevId, MAIN_CH, &stFrame, sReserved);

        /* time is up */
        if ((u32EndTs - u32StartTs) >= s32SaveTime) {
            AK_BASE_PrintNormal(MODULE_ID_APP, "*** timp is up, start_ts = %lld, \
             end_ts = %lld, s32SaveTime = %d ***\n\n",
            u32StartTs, u32EndTs, s32SaveTime);
            break;
        }
    }

    AK_BASE_PrintNormalEx(MODULE_ID_APP, "*** capture finish ***\n\n");
    AK_BASE_ThreadExit();
    return NULL;
}

/**
 * Preconditions:
 * 1. T card is already mounted
 * 2. mic or linein must ready
 */

AK_S32 main(AK_S32 s32Argc, AK_CHAR **pchArgv)
{
    /* start the application */
    SDK_RUN_CONFIG_S stConfig = {0};
    stConfig.s32MemTraceFlag = SDK_RUN_NORMAL;
    AK_BASE_SdkInit(&stConfig);

    if (ParseOption( s32Argc, pchArgv ) == 0) {
        goto Mainend;
    }
    AK_BASE_PrintNormal(MODULE_ID_APP, "*****************************************\n");
    AK_BASE_PrintNormal(MODULE_ID_APP, "** audio input version: %s **\n", AK_MPI_AI_GetVersion());
    AK_BASE_PrintNormal(MODULE_ID_APP, "** effect version: %s **\n", AK_MPI_AUDIO_EFFECT_GetFilterVersion());
    AK_BASE_PrintNormal(MODULE_ID_APP, "** npu version: %s **\n", AK_MPI_NPU_GetVersion());
    AK_BASE_PrintNormal(MODULE_ID_APP, "*****************************************\n");


    AK_S32 s32Ret = -1;
    /*init audio input*/
    if (InitAi()) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "init audio input failed\n");
        goto AIEnd;
    }
    /*init cry*/
    if (InitCry()) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "init Cry failed\n");
        goto CryEnd;
    }

    if (InitSsl()) {
        AK_BASE_PrintErrorEx(MODULE_ID_APP, "init Ssl by conf failed\n");
        goto CryEnd;
    }
   /*open file*/
    if (0 > OpenPcmFile(s32SampleRate, s32SoundMode, spchPcmPath, &pFp1, s32SaveTime, s32AiDevId)) {
        goto CloseFileEnd;
    }
    AK_BASE_SleepMs(1000);
    if (0 > OpenPcmFile(s32SampleRate, s32SoundMode, spchPcmPath, &pFp2, s32SaveTime, s32AiDevId)) {
        goto CloseFileEnd;
    }
    AK_BASE_SleepMs(1000);
    if (0 > OpenPcmFile(s32SampleRate, s32SoundMode, spchPcmPath, &pFp3, s32SaveTime, s32AiDevId)) {
        goto CloseFileEnd;
    }
    /*create get_frame thread*/
    AK_PTHREAD_T CryLoopTid;
    s32Ret = AK_BASE_ThreadCreate(&(CryLoopTid), AiGetFrameLoopAndCryDetect, NULL, ANYKA_THREAD_MIN_STACK_SIZE, 19);
    if (s32Ret) {
        goto CloseFileEnd;
    }

    /*create get_frame thread*/
    AK_PTHREAD_T LsslLoopTid;
    s32Ret = AK_BASE_ThreadCreate(&(LsslLoopTid), AiGetFrameLoopAndSsl, NULL, ANYKA_THREAD_MIN_STACK_SIZE, 19);
    if (s32Ret) {
        goto CloseFileEnd;
    }
    /*create get_frame thread*/
    AK_PTHREAD_T CaptureLoopTid;
    s32Ret = AK_BASE_ThreadCreate(&(CaptureLoopTid), AiGetFrameLoop, NULL, ANYKA_THREAD_MIN_STACK_SIZE, 19);
    if (s32Ret) {
        goto CloseFileEnd;
    }

    /* wait thread end */
    AK_BASE_ThreadJoin(CryLoopTid);
    AK_BASE_ThreadJoin(LsslLoopTid);
    AK_BASE_ThreadJoin(CaptureLoopTid);

CloseFileEnd:
    ClosePcmFile(pFp1);
    ClosePcmFile(pFp2);
    ClosePcmFile(pFp3);

CryEnd:
    DestroyCry();
    DestroySsl();

AIEnd:
    DestroyAi();
Mainend:
    AK_BASE_PrintNoticeEx(MODULE_ID_APP, "******** exit audio input cry detect sample ********\n");
    AK_BASE_SdkExit();
    return s32Ret;
}