
package mods.gift_collector;

import mods.api.Context;
import mods.api.Mod;
import account.GiftInfo;
import town.HomeState;
import flash.events.Event;
import brain.stateMachine.State;
import brain.stateMachine.StateMachine;
import stateMachine.mainStateMachine.LoadingScreenState;

class Main extends Mod {

    private var Context:Context;
    private var homeStateListenerRegistered:Bool = false;

    override public function init(context:Context):Void {

        this.Context = context;

        context.core.onStateEnter(
            function(machine:StateMachine, state:State) {

                if (Std.isOfType(state, LoadingScreenState)){
                    var loadingScreenState:LoadingScreenState = cast state;

                    var accountInfo:Dynamic = loadingScreenState.mDBFacade.dbAccountInfo;

                    if (accountInfo == null)
                        return;

                    var items:Array<Dynamic> = processInventory(accountInfo);

                    accountInfo.getGiftData(function() {

                        var gifts:Array<GiftInfo> = getAllGifts(accountInfo);

                        acceptRelevantGifts(accountInfo, items, gifts);
                    });
                }
                if (Std.isOfType(state, HomeState)){
                      var homeState:HomeState = cast state;

                    var giftAlertUp:Dynamic = Reflect.field(homeState, "mGiftAlertUp");
                    var giftAlertOver:Dynamic = Reflect.field(homeState, "mGiftAlertOver");

                    if (giftAlertUp != null && giftAlertUp.parent != null)
                        giftAlertUp.parent.removeChild(giftAlertUp);

                    if (giftAlertOver != null && giftAlertOver.parent != null)
                        giftAlertOver.parent.removeChild(giftAlertOver);
                }
            }
 
        );
    }


    override public function ready(context:Context):Void {

        this.Context = context;

        var cls = Type.resolveClass("mods.online_tracker.Main");

        if (cls != null) {

            var facade:Dynamic = Reflect.getProperty(context.core, "facade");

            if (facade == null)
                return;

            var eventManager:Dynamic = Reflect.getProperty(facade, "eventManager");

            if (eventManager == null)
                return;

            var eventListener:Dynamic = null;

            eventListener = function(event:Event) {
                eventManager.removeEventListener("GIFTS_LOADED_EVENT",eventListener);

                var accountInfo:Dynamic = Reflect.getProperty(
                    facade,
                    "dbAccountInfo"
                );

                if (accountInfo != null) {

                    var items:Array<Dynamic> = processInventory(accountInfo);

                    var gifts:Array<GiftInfo> = getAllGifts(accountInfo);

                    acceptRelevantGifts(accountInfo, items, gifts);
                }

                registerHomeStateListener();
            };

            eventManager.addEventListener("GIFTS_LOADED_EVENT",eventListener);

        } else {

            registerHomeStateListener();
        }
    }

    // ========================================
    // HOMESTATE LISTENER
    // ========================================

    private function registerHomeStateListener():Void {

        if (homeStateListenerRegistered)
            return;

        homeStateListenerRegistered = true;

        Context.core.onStateEnter(
            function(machine:StateMachine, state:State) {

                if (!Std.isOfType(state, HomeState))
                    return;

                var homeState:HomeState = cast state;

                var accountInfo:Dynamic = homeState.mDBFacade.dbAccountInfo;

                if (accountInfo == null)
                    return;

                var items:Array<Dynamic> = processInventory(accountInfo);

                accountInfo.getGiftData(function() {

                    var gifts:Array<GiftInfo> = getAllGifts(accountInfo);

                    acceptRelevantGifts(accountInfo, items, gifts);

                });
            }
        );
    }

    private function acceptRelevantGifts(accountInfo:Dynamic,items:Array<Dynamic>,gifts:Array<GiftInfo>):Void {

        var itemCounts:Map<Int, Int> = new Map();

        for (item in items) {

            var itemId:Int = Reflect.field(item, "mGMId");
            var count:Int = Reflect.field(item, "mCount");

            itemCounts.set(itemId, count);
        }

        var offers:Map<Int, Int> = new Map();

        offers.set(51399, 70016);
        offers.set(51301, 60001);
        offers.set(51398, 70017);

        for (gift in gifts) {

            var offerId:Int = gift.offerId;

            if (!offers.exists(offerId))
                continue;

            var itemId:Int = offers.get(offerId);

            var count:Int = itemCounts.exists(itemId)
                ? itemCounts.get(itemId)
                : 0;

            if (count >= 99)
                continue;

            accountInfo.acceptGift(
                gift.requestId,
                function() {}
            );

            itemCounts.set(itemId, count + 1);
        }
    }


    // ========================================
    // INVENTORY
    // ========================================

    private function processInventory(accountInfo:Dynamic):Array<Dynamic> {

        var result:Array<Dynamic> = [];

        if (accountInfo == null)
            return result;

        var inventory:Dynamic = Reflect.getProperty(
            accountInfo,
            "mInventory"
        );

        if (inventory == null)
            return result;

        var stackables:Dynamic = Reflect.getProperty(
            inventory,
            "mStackablesByStackableId"
        );

        if (stackables == null)
            return result;

        var keysToArray = Reflect.field(stackables, "keysToArray");
        var itemFor = Reflect.field(stackables, "itemFor");

        if (keysToArray == null || itemFor == null)
            return result;

        var keys:Array<Dynamic> = cast Reflect.callMethod(
            stackables,
            keysToArray,
            []
        );

        if (keys == null)
            return result;

        for (key in keys) {

            if (key != 60001 && key != 70016 && key != 70017)
                continue;

            var item:Dynamic = Reflect.callMethod(
                stackables,
                itemFor,
                [key]
            );

            if (item == null)
                continue;

            result.push(item);
        }

        return result;
    }

    // ========================================
    // GET ALL GIFTS
    // ========================================

    private function getAllGifts(accountInfo:Dynamic):Array<GiftInfo> {

        var result:Array<GiftInfo> = [];

        if (accountInfo == null)
            return result;

        var gifts:Dynamic = Reflect.getProperty(accountInfo, "gifts");

        if (gifts == null)
            return result;

        var keysToArray:Dynamic = Reflect.field(gifts, "keysToArray");
        var itemFor:Dynamic = Reflect.field(gifts, "itemFor");

        if (keysToArray == null || itemFor == null)
            return result;

        var keys:Dynamic = Reflect.callMethod(
            gifts,
            keysToArray,
            []
        );

        if (keys == null)
            return result;

        var giftKeys:Array<Dynamic> = cast keys;

        for (key in giftKeys) {

            var gift:Dynamic = Reflect.callMethod(
                gifts,
                itemFor,
                [key]
            );

            if (gift == null)
                continue;

            result.push(cast gift);
        }

        return result;
    }
}
