"use client";

import { useState } from "react";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-stark";

export const Counter = () => {
  const [newValue, setNewValue] = useState<string>("");

  const { data: counterValue, isLoading, error, refetch } = useScaffoldReadContract({
    contractName: "CounterContract",
    functionName: "get_counter",
  });

  const {
    sendAsync: increaseCounter,
    isPending: isIncreasing,
  } = useScaffoldWriteContract({
    contractName: "CounterContract",
    functionName: "increase_counter",
    args: [],
  });

  const {
    sendAsync: decreaseCounter,
    isPending: isDecreasing,
  } = useScaffoldWriteContract({
    contractName: "CounterContract",
    functionName: "decrease_counter",
    args: [],
  });

  const {
    sendAsync: setCounter,
    isPending: isSetting,
  } = useScaffoldWriteContract({
    contractName: "CounterContract",
    functionName: "set_counter",
    args: [parseInt(newValue) || 0],
  });

  const {
    sendAsync: resetCounter,
    isPending: isResetting,
  } = useScaffoldWriteContract({
    contractName: "CounterContract",
    functionName: "reset_counter",
    args: [],
  });

  const handleIncrease = async () => {
    try {
      await increaseCounter();
      // Refetch the counter value after successful transaction
      setTimeout(() => refetch(), 2000);
    } catch (error) {
      console.error("Error increasing counter:", error);
    }
  };

  const handleDecrease = async () => {
    try {
      await decreaseCounter();
      // Refetch the counter value after successful transaction
      setTimeout(() => refetch(), 2000);
    } catch (error) {
      console.error("Error decreasing counter:", error);
    }
  };

  const handleSetCounter = async () => {
    if (!newValue || isNaN(parseInt(newValue))) {
      alert("Please enter a valid number");
      return;
    }
    
    try {
      await setCounter({ args: [parseInt(newValue)] });
      setNewValue(""); // Clear input after successful transaction
      // Refetch the counter value after successful transaction
      setTimeout(() => refetch(), 2000);
    } catch (error) {
      console.error("Error setting counter:", error);
      // Check if it's an ownership error
      const errorMessage = (error as any)?.message || error?.toString() || "Unknown error";
      if (errorMessage.includes("Caller is not the owner") || errorMessage.includes("only_owner")) {
        alert("Only the contract owner can set the counter value");
      } else {
        alert(`Error setting counter: ${errorMessage}`);
      }
    }
  };

  const handleResetCounter = async () => {
    const confirmReset = confirm(
      "⚠️ Reset Counter requires payment of 1 STRK token.\n\n" +
      "This will:\n" +
      "• Reset counter to 0\n" +
      "• Transfer 1 STRK from your wallet to the contract owner\n" +
      "• Requires sufficient STRK balance and approval\n\n" +
      "Do you want to continue?"
    );

    if (!confirmReset) return;

    try {
      await resetCounter();
      // Refetch the counter value after successful transaction
      setTimeout(() => refetch(), 2000);
    } catch (error) {
      console.error("Error resetting counter:", error);
      const errorMessage = (error as any)?.message || error?.toString() || "Unknown error";
      
      if (errorMessage.includes("Insufficient STRK balance")) {
        alert("❌ Insufficient STRK balance. You need at least 1 STRK token to reset the counter.");
      } else if (errorMessage.includes("Insufficient STRK allowance")) {
        alert("❌ Insufficient STRK allowance. Please approve the contract to spend 1 STRK token first.");
      } else if (errorMessage.includes("STRK transfer failed")) {
        alert("❌ STRK transfer failed. Please check your wallet and try again.");
      } else {
        alert(`❌ Error resetting counter: ${errorMessage}`);
      }
    }
  };

  if (isLoading) {
    return (
      <div className="flex flex-col items-center p-6 bg-base-100 rounded-lg shadow-lg">
        <h2 className="text-2xl font-bold mb-4">Counter Value</h2>
        <div className="loading loading-spinner loading-lg"></div>
        <p className="text-sm text-gray-500 mt-2">Loading counter...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center p-6 bg-base-100 rounded-lg shadow-lg">
        <h2 className="text-2xl font-bold mb-4 text-error">Error Loading Counter</h2>
        <p className="text-error text-sm mb-4">{error.message}</p>
        <button 
          className="btn btn-error btn-sm" 
          onClick={() => refetch()}
        >
          Retry
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center p-6 bg-base-100 rounded-lg shadow-lg max-w-md">
      <h2 className="text-2xl font-bold mb-4">Smart Contract Counter</h2>
      
      {/* Counter Display */}
      <div className="text-6xl font-mono font-bold text-white mb-6">
        {counterValue?.toString() || "0"}
      </div>

      {/* Action Buttons */}
      <div className="flex gap-4 mb-4">
        <button 
          className={`btn btn-success ${isIncreasing ? 'loading' : ''}`}
          onClick={handleIncrease}
          disabled={isIncreasing || isDecreasing || isSetting || isResetting}
        >
          {isIncreasing ? (
            <>
              <span className="loading loading-spinner loading-sm"></span>
              Increasing...
            </>
          ) : (
            <>
              <svg 
                xmlns="http://www.w3.org/2000/svg" 
                className="h-5 w-5 mr-2" 
                fill="none" 
                viewBox="0 0 24 24" 
                stroke="currentColor"
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
              </svg>
              Increase (+1)
            </>
          )}
        </button>

        <button 
          className={`btn btn-warning ${isDecreasing ? 'loading' : ''}`}
          onClick={handleDecrease}
          disabled={isIncreasing || isDecreasing || isSetting || isResetting}
        >
          {isDecreasing ? (
            <>
              <span className="loading loading-spinner loading-sm"></span>
              Decreasing...
            </>
          ) : (
            <>
              <svg 
                xmlns="http://www.w3.org/2000/svg" 
                className="h-5 w-5 mr-2" 
                fill="none" 
                viewBox="0 0 24 24" 
                stroke="currentColor"
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20 12H4" />
              </svg>
              Decrease (-1)
            </>
          )}
        </button>
      </div>

      {/* Set Counter Section */}
      <div className="w-full max-w-xs mb-4">
        <div className="flex gap-2">
          <input
            type="number"
            placeholder="Enter value"
            className="input input-bordered input-sm flex-1"
            value={newValue}
            onChange={(e) => setNewValue(e.target.value)}
            disabled={isIncreasing || isDecreasing || isSetting || isResetting}
            min="0"
          />
          <button 
            className={`btn btn-primary btn-sm ${isSetting ? 'loading' : ''}`}
            onClick={handleSetCounter}
            disabled={isIncreasing || isDecreasing || isSetting || isResetting || !newValue}
          >
            {isSetting ? (
              <>
                <span className="loading loading-spinner loading-xs"></span>
                Setting...
              </>
            ) : (
              <>
                <svg 
                  xmlns="http://www.w3.org/2000/svg" 
                  className="h-4 w-4 mr-1" 
                  fill="none" 
                  viewBox="0 0 24 24" 
                  stroke="currentColor"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
                Set
              </>
            )}
          </button>
        </div>
        <p className="text-xs text-gray-400 mt-1 text-center">
          ⚠️ Owner only function
        </p>
      </div>

      {/* Reset Counter Section */}
      <div className="w-full max-w-xs mb-4">
        <button 
          className={`btn btn-error btn-sm w-full ${isResetting ? 'loading' : ''}`}
          onClick={handleResetCounter}
          disabled={isIncreasing || isDecreasing || isSetting || isResetting}
        >
          {isResetting ? (
            <>
              <span className="loading loading-spinner loading-xs"></span>
              Resetting...
            </>
          ) : (
            <>
              <svg 
                xmlns="http://www.w3.org/2000/svg" 
                className="h-4 w-4 mr-2" 
                fill="none" 
                viewBox="0 0 24 24" 
                stroke="currentColor"
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              💰 Reset Counter (1 STRK)
            </>
          )}
        </button>
        <p className="text-xs text-gray-400 mt-1 text-center">
          💸 Requires 1 STRK token payment
        </p>
      </div>

      {/* Refresh Button */}
      <button 
        className="btn btn-outline btn-sm mb-2" 
        onClick={() => refetch()}
        title="Refresh counter value"
      >
        <svg 
          xmlns="http://www.w3.org/2000/svg" 
          className="h-4 w-4 mr-2" 
          fill="none" 
          viewBox="0 0 24 24" 
          stroke="currentColor"
        >
          <path 
            strokeLinecap="round" 
            strokeLinejoin="round" 
            strokeWidth={2} 
            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" 
          />
        </svg>
        Refresh
      </button>

      <p className="text-xs text-gray-500 text-center">
        Interact with your deployed smart contract<br/>
        Auto-updates when contract state changes
      </p>
    </div>
  );
};