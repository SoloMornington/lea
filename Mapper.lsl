// Mapmaker
//
// History:
//
// - a PHP script was created by Lex Mars (founder of Subnova); it accesses the map tiles and returns a texture UUID
// - a small example script (including the URL) was published in the LSL Wiki Script Library
// - the script uses a HTTP request (I used that as a starting point) to retrieve the texture UUID of the map
//

// Author: Runay Roussel
// Released to the public domain on September 14th, 2009

// Loads of updates for LEA by Solo Mornington circa 2012
// - Works with link sets. One script for many prims.
// - Sim name is retrieved from prim description field.
// - Updated for llRegionSayTo().

// How to use:
// - Make some prims.
// - Put sim names in the prims' description field.
// - Link the prims.
// - Put this script in the linkset.
// - Voila.


float gMapResetTime = 86400.0;  // timer interval = 24 hours
float gTimeout = 30.0;
key request;           // handle for HTTP request
string URL = "http://www.subnova.com/secondlife/api/map.php";  // URL of PHP script
string full_URL;       // full URL including sim name

integer gCurrentTile; // which prim are we getting the map for?
string gCurrentSim; // name of sim for that prim.

list gSimNames; // as derived from prim descs
list gSimTextures; // indexed to gSimName

key gMysterySim = "89f68ffb-e4c7-9390-cff7-ee64ce9a185c"; // unknown map tile


clearAllText()
{
    // remove all prim hover texts
    llSetLinkPrimitiveParamsFast(LINK_SET, [PRIM_TEXT, "", <1,1,1>, 1.0]);
}

string capitalize (string text)
{
    return llToUpper(llGetSubString(text, 0, 0)) + llGetSubString(text, 1, -1);
}

string getPrimDesc(integer prim)
{
    list descList = llGetLinkPrimitiveParams(prim, [PRIM_DESC]);
    return llList2String(descList,0);
}

setPrimText(integer prim, string text)
{
    llSetLinkPrimitiveParamsFast(prim, [PRIM_TEXT, text, <1,1,1>, 1.0]);
}

setTexture(integer prim, key texture)
{
    llSetLinkPrimitiveParamsFast(prim, [
        PRIM_TEXTURE, 1, texture, <1,1,1>, <0,0,0>, 0.0]);
}

gatherSimNames()
{
    // gather the sim names from the prim descs.
    gSimNames = [];
    gSimTextures = [];
    integer prim = 0;
    integer primCount = llGetObjectPrimCount(llGetKey());
    if (primCount > 1) prim = 1;
    for ( ;prim <= primCount; ++prim)
    {
        string simName = getPrimDesc(prim);
        if (simName != "")
        {
            gSimNames += simName;
            gSimTextures += gMysterySim;
            setPrimText(prim, simName);
        }
    }
}

integer getNextTile()
{
    // send a request for the next tile
    // we return TRUE if a request was sent
    // FALSE otherwise.
    ++gCurrentTile;
    gCurrentSim = "";
    if (gCurrentTile < llGetListLength(gSimNames))
    {
        getMapTile(llList2String(gSimNames,gCurrentTile));
        return TRUE;
    }
    return FALSE;
}

getMapTile(string sim_name)
{
    full_URL = URL + "?sim=" + llEscapeURL(sim_name);
    request = llHTTPRequest(full_URL, [], "");
    llSetTimerEvent(0);
    llSetTimerEvent(gTimeout);
}


default
{
    // in state default we cycle through all the prims, and
    // prim descriptions will be sent as queries to see
    // which map tile they should show.
    state_entry()
    {
        clearAllText();
        llSetText("Initializing map...", <1,1,1>, 1.0);
        gatherSimNames();
        llSetTimerEvent(gTimeout);
        gCurrentTile = -1;
        gCurrentSim = "";
        if (!getNextTile()) state clickyMap;
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (status == 200) {
            if ((key)body) {
                gSimTextures = llListReplaceList(gSimTextures, [(key)body], gCurrentTile, gCurrentTile);
            }
        }
        if (!getNextTile()) state clickyMap;
    }
    
    timer()
    {
        // this ridiculously obtuse process (thanks, linden lab!)
        // timed out. So let's tell the user and bail.
        llSetTimerEvent(0.0);
        llSay(0, "Unable to gather all the map tiles before time ran out. Click to try again.");
        state iAmDead;
    }
    
    state_exit()
    {
        // now we apply all the maps.
        integer i = 1;
        integer count = llGetObjectPrimCount(llGetKey());
        if (count < 2) i = 0; // stupid LL.
        for (; i<=count; ++i)
        {
            string desc = getPrimDesc(i);
            if (desc != "")
            {
                integer index = llListFindList(gSimNames, [desc]);
                if (index > -1)
                {
                    setTexture(i, llList2Key(gSimTextures,index));
                }
            }
        }
    }
}

state clickyMap
{
    state_entry()
    {
        llSetTimerEvent(gMapResetTime);
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }

    timer()
    {
        llSetTimerEvent(0.0);
        state default;
    }

    touch_start(integer total_number)
    {
        integer i;
        for (i=0; i<total_number; ++i)
        {
            integer link = llDetectedLinkNumber(i);
            string sim = getPrimDesc(link);
            if (sim != "")
            {
                llRegionSayTo(llDetectedKey(i), 0, "Teleport by clicking here: secondlife:///app/teleport/" + sim + "/128/128/51/");
            }
        }
    }
}

state iAmDead
{
    state_entry()
    {
        clearAllText();
    }
    
    touch_start(integer foo)
    {
        llSay(0,"Restarting...");
        state default;
    }
}
