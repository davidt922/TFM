pragma solidity ^0.4.18;

/**
 * Add oraclize API
 */
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

/**
 * Allow Slice strings
 */
import "github.com/Arachnid/solidity-stringutils/strings.sol";

contract MarketData is usingOraclize
{
  /**
   * To enable strings.sol library
   */
  using strings for *;


  event LogConstructorInitiated(string nextStep);
  event LogNewOraclizeQuery(string description);
  event returnCurrencyExchange(string currExchange);
  event returnETHPrice(string ethPrice);

  mapping(bytes32 => uint) queryIdToFunctionNumber;
  mapping(bytes32 => address) queryIdToContractAddressThatHaveCalledTheFunction;

  function MarketData() public payable
  {
    LogConstructorInitiated("Constructor was initiated. Call 'updatePrice()' to send the Oraclize Query.");
  }

  /**
   * The base coin can only be EUR, for other coins you neew a premium fixer.io account
   * _base and _secundary with ISO 4217
   * Function number 1
   */
  function getCurrencyExchange(string _base, string _secundary) public  payable
  {
    if (oraclize_getPrice("URL") > this.balance)
    {
      LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    }
    else
    {
      string memory string1 = "json(http://data.fixer.io/api/latest?access_key=c06c3bdf5ea5e65c2dfb574f744725c4&base=";
      string memory string2 = _base;
      string memory string3 = "&symbols=";
      string memory string4 = _secundary;
      string memory string5 = ").rates.";

      string memory querys1 = strConcat(string1, string2, string3, string4);
      string memory query = strConcat(querys1, string5, string4);

      LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
      bytes32 queryID = oraclize_query("URL",query);
      queryIdToFunctionNumber[queryID] = 1;
    }
  }
  /**
   * Get the actual ETH price with respect to a currency
   * _baseCurrency ISO 4217
   * Function number 3
   */
  function getETHPrice(string _baseCurrency) public  payable
  {
    /**
     * this.balance is the number of ETH stored in the contract,
     * msg.value is the amount of ETH send to a public payable method
     */
    if (oraclize_getPrice("URL") > this.balance)
    {
      LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    }
    else
    {
        string memory URL = "json(https://api.kraken.com/0/public/Ticker?pair=ETH";
        string memory baseCurrency = _baseCurrency;
        string memory query1 = ").result.XETHZ";
        string memory query2 = ".c.0";

        string memory query = strConcat(URL, baseCurrency, query1,baseCurrency, query2);

        LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
        bytes32 queryID = oraclize_query("URL",query);
        queryIdToFunctionNumber[queryID] = 3;
    }
  }

  function getIMSwap(string _nominal, string _instrumentID) public  payable
  {
    string probability = "0.95";
    if (oraclize_getPrice("URL") > this.balance)
    {
      LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    }
    else
    {
      string memory query = "json(https://empty-lion-93.localtunnel.me/BOE/computeVaR/"+probability+"/"+_nominal+"/"+_instrumentID+"/).*"
      LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
      bytes32 queryID = oraclize_query("URL",query);
      queryIdToContractAddressThatHaveCalledTheFunction[queryID] = msg.sender;
      queryIdToFunctionNumber[queryID] = 4;
    }

  }

  function __callback(bytes32 myid, string result)
  {
    if (msg.sender != oraclize_cbAddress())
    {
      revert();
    }

    uint functionNumber = queryIdToFunctionNumber[myid];
    address contractAddress = queryIdToContractAddressThatHaveCalledTheFunction[myid];

    if(functionNumber == 1)
    {
      returnCurrencyExchange(result);
    }
    else if(functionNumber == 2)
    {
      returnCurrencyExchange(result);
    }
    else if(functionNumber == 3)
    {
      returnETHPrice(result);
    }
    else if(functionNumber == 4)
    {
      returnETHPrice(result);
    }
  }

}