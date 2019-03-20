integer g_iBuild = 1;

string g_sAppVersion = "⁰⋅¹";

string g_sParentMenu = "Apps";
string g_sSubMenu = "Group Access";

string g_sGroupId = "";

string g_sSettingToken = "grpaccess_";

integer CMD_ZERO = 0;

integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_SAFEWORD = 510;

integer NOTIFY = 1002;
integer SAY = 1004;
integer REBOOT = -1000;
integer LINK_AUTH = 2;
integer LINK_DIALOG = 3;
integer LINK_RLV = 4;
integer LINK_SAVE = 5;
integer LINK_UPDATE = -10;
integer LM_SETTING_SAVE = 2000;
integer LM_SETTING_RESPONSE = 2002;
integer LM_SETTING_DELETE = 2003;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer BUILD_REQUEST = 17760501;


string g_sButtonON = "☑ ON";
string g_sButtonOFF = "☐ OFF";
string g_sButtonBack = "BACK";

integer g_iOn = TRUE;

string  g_sTempOwnerID;
key g_kWearer;

list g_lMenuIDs;
integer g_iMenuStride = 3;

key GetGroupKey(key kId) {
    if (llSameGroup(kId)) {
        return llList2Key(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0);
    } else {
        list lAttached = llGetAttachedList(kId);
        if (llGetListLength(lAttached)) {
            return llList2Key(llGetObjectDetails(llList2Key(lAttached, 0), [OBJECT_GROUP]), 0);
        }
    }
    return "";
}

Dialog(key kId, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string iMenuType) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_DIALOG, DIALOG, (string)kId + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kId]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kId, kMenuID, iMenuType], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kId, kMenuID, iMenuType];
}

ConfigMenu(key kId, integer iAuth) {
    string sPrompt = "\nSR Access\n";
    list lMyButtons;

    if (kId == g_kWearer) {
        if (g_iOn) {
            lMyButtons += g_sButtonON;
        } else {
            lMyButtons += g_sButtonOFF;
        }
        Dialog(kId, sPrompt, lMyButtons, ["BACK"], 0, iAuth, "ConfigMenu");
    } else {
        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"This feature is only for the wearer of the collar.", kId);
    }

}

saveTempOwners() {
    if (g_sTempOwnerID) {
        llMessageLinked(LINK_SAVE, LM_SETTING_SAVE, "auth_tempowner="+g_sTempOwnerID, "");
        llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "auth_tempowner="+g_sTempOwnerID, "");
    } else {
        llMessageLinked(LINK_SET, LM_SETTING_RESPONSE, "auth_tempowner=", "");
        llMessageLinked(LINK_SAVE, LM_SETTING_DELETE, "auth_tempowner", "");
    }
}

doCapture(string sCaptorID) {
    if (!g_iOn) return;

    if (g_sGroupId) {
        if (g_sGroupId != GetGroupKey(sCaptorID)) return;

        llMessageLinked(LINK_DIALOG, NOTIFY, "0"+"Access granted to %WEARERNAME%'s %DEVICETYPE% by Sunstone Ranch Access plugin.", sCaptorID);
        g_sTempOwnerID = "";
        saveTempOwners();
        llSleep(1.0);
        g_sTempOwnerID = sCaptorID;
        saveTempOwners();
        llSleep(1.0);
        llMessageLinked(LINK_AUTH,CMD_ZERO,"menu",sCaptorID);

        llSetTimerEvent(900.0);
    }
}

UserCommand(integer iNum, string sStr, key kId, integer remenu) {
    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand = llToLower(llList2String(lParams, 0));
    string sAction = llToLower(llList2String(lParams, 1));
    string sLowerStr = llToLower(sStr);
    if (llSubStringIndex(sStr,"sr access TempOwner") == 0){
        string sCaptorID = llGetSubString(sStr,llSubStringIndex(sStr,"~")+1,-1);
        if (iNum == CMD_OWNER || iNum == CMD_WEARER) { }
        else {
            doCapture(sCaptorID);
        }
    } else if (sLowerStr == "menu sr access" || sLowerStr == "sraccess") {
        ConfigMenu(kId, iNum);
    } else if (sCommand == "sraccess") {
        if (kId == g_kWearer) {
            if (sAction == "on") {
                g_iOn = TRUE;
                llMessageLinked(LINK_SAVE, LM_SETTING_SAVE,g_sSettingToken+"active=1", "");
            } else if (sAction == "off") {
                g_iOn = FALSE;
                llMessageLinked(LINK_SAVE, LM_SETTING_DELETE,g_sSettingToken+"active", "");
            }
        }
    }
    if (kId == g_sTempOwnerID) {
        llSetTimerEvent(900.0);
    }
    if (remenu) ConfigMenu(kId, iNum);
}

default
{
    state_entry() {
        g_kWearer = llGetOwner();
    }

    on_rez(integer iParam) {
        if (llGetOwner()!=g_kWearer)  llResetScript();
    }

    touch_start(integer num_detected) {
        key kToucher = llDetectedKey(0);
        if (kToucher == g_kWearer) return;
        if (g_sTempOwnerID == kToucher) return;
        if (!g_iOn) return;
        else llMessageLinked(LINK_AUTH,CMD_ZERO,"sraccess TempOwner~"+(string)kToucher,kToucher);
    }

    link_message(integer iSender, integer iNum, string sStr, key kId) {
        if (iNum >= CMD_OWNER && iNum <= CMD_WEARER) {
            UserCommand(iNum, sStr, kId, FALSE);
        } else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) {
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        } else if (iNum == CMD_SAFEWORD || (sStr == "runaway" && iNum == CMD_OWNER)) {
            if (iNum == CMD_SAFEWORD && g_iOn) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"SR Access plugin deactivated.", g_kWearer);
            if (llGetAgentSize(g_sTempOwnerID)) llMessageLinked(LINK_DIALOG,NOTIFY,"0"+"%WEARERNAME% has either run away or safeworded, SR Access plugin was deactivated.",g_sTempOwnerID);
            g_iOn = FALSE;
            llMessageLinked(LINK_SAVE, LM_SETTING_DELETE,g_sSettingToken+"active", "");
            g_sTempOwnerID = "";
            saveTempOwners();
        } else if (iNum == LM_SETTING_RESPONSE) {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);

            if (sToken == g_sSettingToken+"active") g_iOn = (integer)sValue;
            else if (sToken == "auth_tempowner") g_sTempOwnerID = sValue;

        } else if (iNum >= CMD_OWNER && iNum <= CMD_EVERYONE) UserCommand(iNum, sStr, kId, FALSE);
        else if (iNum == DIALOG_RESPONSE) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kId]);
            if (~iMenuIndex) {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                string sMenu=llList2String(g_lMenuIDs, iMenuIndex+1);
                key kCaptor=llList2Key(g_lMenuIDs, iMenuIndex + 2);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +2);

                if (sMenu=="ConfigMenu") {
                    if (sMessage == "BACK") llMessageLinked(LINK_ROOT, iAuth, "menu " + g_sParentMenu, kAv);
                    else if (sMessage == g_sButtonON) UserCommand(iAuth, "sraccess off", kAv, TRUE);
                    else if (sMessage == g_sButtonOFF) UserCommand(iAuth, "sraccess on", kAv, TRUE);
                    else UserCommand(iAuth,"sraccess " + sMessage, kAv, TRUE);
                }
            }
        } else if (iNum == DIALOG_TIMEOUT) {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kId]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +2);
        } else if (iNum == LINK_UPDATE) {
            if (sStr == "LINK_AUTH") LINK_AUTH = iSender;
            else if (sStr == "LINK_DIALOG") LINK_DIALOG = iSender;
            else if (sStr == "LINK_RLV") LINK_RLV = iSender;
            else if (sStr == "LINK_SAVE") LINK_SAVE = iSender;
        } else if (iNum == BUILD_REQUEST)
            llMessageLinked(iSender,iNum+g_iBuild,llGetScriptName(),"");
        else if (iNum == REBOOT && sStr == "reboot") llResetScript();
    }

    timer()
    {
        g_sTempOwnerID = "";
        saveTempOwners();
    }
}