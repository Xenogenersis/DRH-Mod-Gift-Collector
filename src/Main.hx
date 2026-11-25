
package mods.gift_collector;

import mods.api.Context;
import mods.api.Mod;
import account.GiftInfo;
import town.HomeState;
import brain.stateMachine.State;
import brain.stateMachine.StateMachine;
import stateMachine.mainStateMachine.LoadingScreenState;

class Main extends Mod {
    private var context:Context;
    
    private var savedGiftAlertUp:Dynamic;
    private var savedGiftAlertOver:Dynamic;
    private var currentHomeState:HomeState;

    private var savedGiftAlertUpParent:Dynamic;
    private var savedGiftAlertOverParent:Dynamic;

    private var hideGiftAlert;
    private var acceptHealthBomb;
    private var acceptHealthShot;
    private var acceptManaShot;

    override public function init(context:Context):Void {
        this.context = context;
        this.hideGiftAlert = context.settings.flag("hide_gift_alert","Hide gift alert","Hide the gift notification in town.",true);

        this.acceptHealthBomb = context.settings.flag("accept_health_bomb","Accept Health Bomb","Automatically accept Health Bomb gifts.",true);

        this.acceptHealthShot = context.settings.flag("accept_health_shot","Accept Health Shot","Automatically accept Health Shot gifts.",true);

        this.acceptManaShot = context.settings.flag("accept_mana_shot","Accept Mana Shot","Automatically accept Mana Shot gifts.",true);

        this.hideGiftAlert.onChange(function(enabled:Bool) {
            if (this.currentHomeState != null) {
                updateGiftAlert();
            }
        });

        context.core.onStateEnter(
            function(machine:StateMachine, state:State) {

                if (Std.isOfType(state, LoadingScreenState)) {

                    if (!this.acceptManaShot.value &&!this.acceptHealthShot.value &&!this.acceptHealthBomb.value)
                        return;

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

                if (Std.isOfType(state, HomeState)) {
                    context.log("test");

                    this.currentHomeState = cast state;
                    updateGiftAlert();
                }
            }
        );  
        context.core.onStateExit(function(machine:StateMachine, state:State) {
            if (Std.isOfType(state, HomeState)) {
                this.currentHomeState = null;
            }
        });
    }


    private function updateGiftAlert():Void {

        if (currentHomeState == null)
            return;

        var giftAlertUp:Dynamic = Reflect.field(currentHomeState, "mGiftAlertUp");
        var giftAlertOver:Dynamic = Reflect.field(currentHomeState, "mGiftAlertOver");

        if (hideGiftAlert.value) {

            if (giftAlertUp != null && giftAlertUp.parent != null) {
                savedGiftAlertUp = giftAlertUp;
                savedGiftAlertUpParent = giftAlertUp.parent;
                savedGiftAlertUpParent.removeChild(giftAlertUp);
            }

            if (giftAlertOver != null && giftAlertOver.parent != null) {
                savedGiftAlertOver = giftAlertOver;
                savedGiftAlertOverParent = giftAlertOver.parent;
                savedGiftAlertOverParent.removeChild(giftAlertOver);
            }

        } else {

            if (savedGiftAlertUp != null && savedGiftAlertUpParent != null) {
                if (savedGiftAlertUp.parent == null)
                    savedGiftAlertUpParent.addChild(savedGiftAlertUp);

                savedGiftAlertUp = null;
                savedGiftAlertUpParent = null;
            }

            if (savedGiftAlertOver != null && savedGiftAlertOverParent != null) {
                if (savedGiftAlertOver.parent == null)
                    savedGiftAlertOverParent.addChild(savedGiftAlertOver);

                savedGiftAlertOver = null;
                savedGiftAlertOverParent = null;
            }
        }
    }


    // ========================================
    // ACCEPT RELEVANT GIFTS
    // ========================================

    private function acceptRelevantGifts(accountInfo:Dynamic, items:Array<Dynamic>, gifts:Array<GiftInfo>):Void {

        var itemCounts:Map<Int, Int> = new Map();

        for (item in items) {

            var itemId:Int = Reflect.field(item, "mGMId");
            var count:Int = Reflect.field(item, "mCount");

            itemCounts.set(itemId, count);
        }

        var offers:Map<Int, Int> = new Map();

        if (this.acceptHealthBomb.value)
            offers.set(51301, 60001);

        if (this.acceptHealthShot.value)
            offers.set(51399, 70016);

        if (this.acceptManaShot.value)
            offers.set(51398, 70017);

        var acceptNext:Int->Void;

        acceptNext = function(index:Int):Void {

            if (index >= gifts.length)
                return;

            var gift = gifts[index];

            var offerId:Int = gift.offerId;

            if (!offers.exists(offerId)) {
                acceptNext(index + 1);
                return;
            }

            var itemId:Int = offers.get(offerId);

            var count:Int = itemCounts.exists(itemId)
                ? itemCounts.get(itemId)
                : 0;

            if (count >= 99) {
                acceptNext(index + 1);
                return;
            }

            accountInfo.acceptGift(
                gift.requestId,
                function() {},
                function() {

                    itemCounts.set(itemId, count + 1);

                    acceptNext(index + 1);
                }
            );
        };

        acceptNext(0);
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
