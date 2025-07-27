import Types "../shared/types";
import Interfaces "../shared/interfaces";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Float "mo:base/Float";
import Iter "mo:base/Iter";
import Text "mo:base/Text";

actor MarketMonitor : Interfaces.MarketMonitorInterface {
    // Cached snapshots of market data
    private stable var snapshots_stable : [(Text, Types.MarketSnapshot)] = [];

    // Refresh market rates from external sources (stub implementation)
    public shared(msg) func refresh_rates() : async Types.Result<Text, Types.ApiError> {
        // TODO implement HTTP outcalls to fetch lending rates, TVL, liquidity data
        snapshots_stable := [];
        #ok("rates refreshed");
    };

    // Return the latest cached market snapshots
    public query func latest_rates() : async Types.Result<[Types.MarketSnapshot], Types.ApiError> {
        let result : [Types.MarketSnapshot] = snapshots_stable.vals() |> Iter.toArray(_);
        #ok(result)
    };
}