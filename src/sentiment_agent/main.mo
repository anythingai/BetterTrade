import Types "../shared/types";
import Interfaces "../shared/interfaces";

actor SentimentAgent : Interfaces.SentimentAgentInterface {
    public shared(msg) func refresh_sentiment() : async Types.Result<Float, Types.ApiError> {
        // TODO implement sentiment scoring
        #ok(0.0)
    };

    public query func latest_sentiment() : async Types.Result<Float, Types.ApiError> {
        // TODO return latest sentiment index
        #ok(0.0)
    };
}