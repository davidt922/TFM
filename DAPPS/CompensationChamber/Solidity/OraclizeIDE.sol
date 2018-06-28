pragma solidity ^0.4.18;


import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
import "github.com/Arachnid/solidity-stringutils/strings.sol";

contract conversions
{
  using strings for *;

  // Convert from bytes32 to String
  function bytes32ToString(bytes32 _bytes32) public constant returns (string)
  {
    bytes memory bytesArray = new bytes(32);
    for (uint256 i; i < 32; i++)
    {
        bytesArray[i] = _bytes32[i];
    }
    return string(bytesArray);
  }
  // Convert addressToString
  function addressToString(address x) returns (string)
  {
    bytes memory b = new bytes(20);

    for (uint i = 0; i < 20; i++)
    {
      b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
    }
    return string(b);
  }
  // Convert string to bytes32
  function stringToBytes32(string memory source) public returns (bytes32 result)
  {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0)
    {
        return 0x0;
    }
    assembly
    {
        result := mload(add(source, 32))
    }
}
  // convert string of this type: [aa, bb, cc] to an array of bytes32 ["aa","bb","cc"]
  function stringToBytes32Array(string result) public payable returns (bytes32[])
  {
    // Posible improve here
    var stringToParse = result.toSlice();
    stringToParse.beyond("[".toSlice()).until("]".toSlice()); //remove [ and ]
    var delim = ",".toSlice();
    //var parts = new string[](stringToParse.count(delim) + 1);
    bytes32[] parts;
    for (uint i = 0; i < parts.length; i++)
    {
        parts[i] = stringToBytes32(stringToParse.split(delim).toString());
    }
    // Finish possible improve
    return parts;
  }

  function strConcat(string _a, string _b, string _c, string _d, string _e) internal pure returns (string)
  {
      bytes memory _ba = bytes(_a);
      bytes memory _bb = bytes(_b);
      bytes memory _bc = bytes(_c);
      bytes memory _bd = bytes(_d);
      bytes memory _be = bytes(_e);
      string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
      bytes memory babcde = bytes(abcde);
      uint k = 0;
      for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
      for (i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
      for (i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
      for (i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
      for (i = 0; i < _be.length; i++) babcde[k++] = _be[i];
      return string(babcde);
  }

  function strConcat(string _a, string _b, string _c, string _d) internal pure returns (string)
  {
      return strConcat(_a, _b, _c, _d, "");
  }

  function strConcat(string _a, string _b, string _c) internal pure returns (string)
  {
      return strConcat(_a, _b, _c, "", "");
  }

  function strConcat(string _a, string _b) internal pure returns (string)
  {
      return strConcat(_a, _b, "", "", "");
  }

}

contract compensationChamber is conversions
{
  using strings for *;

  event inicialMargin(string a);
  /**
   * Constants
   */
  uint private dayInSeconds = 86400; // Number of seconds in 24 h

  /**
   * From the moment that the CCP indicates the daily collateral that both counterparts
   * Have to send to the chamber, they have 12 hours to pay it.
   */
  uint private timeToPayTheMargin = 43200;

  /**
   * Address of the compensation chamber and the market
   */
  address private owner;
  address private marketAddress;
  address private marketDataAddress;

  /**
   * Timestamp in seconds since epox indicating the date and time when the chamber will do the
   * next asset valuation and will infrom of the daily marginal that the counterparts have to give to the chamber.
   * Or to liquidate the operation if the contract has reached the maturity date.
   */
  uint private nextRevisionTime;
  uint private deadlineForMarginalPayment;
  bool private marketAddressChange = true;

  /**
   * Map an Ethereum account address with the corresponding clearing member contract address
   */
  mapping (address => address) mapEtherAccountToContractAddress;
  address[] clearingMembersAddresses;
  address[] clearingMemberContractAddresses;
  address[] assets;

  function compensationChamber() public payable
  {
    owner = msg.sender;
    nextRevisionTime = block.timestamp + dayInSeconds;
    deadlineForMarginalPayment = nextRevisionTime + timeToPayTheMargin;
    marketDataAddress = (new MarketData).value(5 ether)();
  }

  function getMarketDataAddress() public payable returns(address)
  {
      return marketDataAddress;
  }


  /**
   * Create the modifiers, this is a pattern that restricts the execution of some functions, read the content of modify the contract
   * also allows to perfom timed transactions
   */
  modifier onlyChamber
  {
    require(msg.sender == owner);
    _;
  }
  modifier onlyMarket
  {
    require(msg.sender == marketAddress);
    _;
  }

  /**
   * Add functions of the smartcontract
   */
  function setMarketAddress(address _marketAddress) onlyChamber public payable
  {
    require(marketAddressChange);
    marketAddressChange = false;
    marketAddress = _marketAddress;
  }

  function addClearingMember(address _clearingMemberAddress) onlyChamber public payable
  {
    address contractAddress = mapEtherAccountToContractAddress[_clearingMemberAddress];

    /**
     * if the contract address is 0, means that he address conrresponds to a new clearing member
     * so a new clearingMember contract have to be created.
     * if the contract exist, revert the changes and send an error message
     */
    if(contractAddress == 0)
    {
      mapEtherAccountToContractAddress[_clearingMemberAddress] = new clearingMember(_clearingMemberAddress);
      clearingMembersAddresses.push(_clearingMemberAddress);
      clearingMemberContractAddresses.push(mapEtherAccountToContractAddress[_clearingMemberAddress]);
    }
    else
    {
      //revert("There is a contract of a liquidator member linked to this address");
    }
  }

  function getDeadlineForMarginalPayment() public payable returns(uint)
  {
    return deadlineForMarginalPayment;
  }

  function getClearingMemberAddresses() public payable returns(address[])
  {
      return clearingMembersAddresses;
  }
  function getContractForAGivenAddress(address _clearingMemberAddress) public payable returns(address)
  {
      return mapEtherAccountToContractAddress[_clearingMemberAddress];
  }

  function sendInitialMarginInformation(bytes32 _initialMargin, address _clearingMemberAddress)
  {
    string memory initialMarginStr = bytes32ToString(_initialMargin);
    string memory clearingMemberAddressStr = addressToString(_clearingMemberAddress);
    string memory logInfo = strConcat(clearingMemberAddressStr,": ",clearingMemberAddressStr);
    inicialMargin(logInfo);
  }


  /**
   * Products
   */
  function addVanillaSwap(address _floatingLegMemberAddress, address _fixedLegMemberAddress, uint _settlementDate, string _nominal, string _instrumentID) /*onlyMarket */payable public
  {
    assets.push( (new vanillaSwap).value(10 ether)(marketDataAddress, mapEtherAccountToContractAddress[_floatingLegMemberAddress], mapEtherAccountToContractAddress[_fixedLegMemberAddress], _settlementDate, _nominal, _instrumentID));
  }
}

contract asset is conversions
{
  using strings for *;

  address marketDataAddress;
  address compensationChamberAddress;
  address contractAddress1; //floating leg
  address contractAddress2; //fixed leg
  uint tradeDate;
  uint settlementDate;
  string nominal;

  /**
   * Map the contractAddress1 and 2 to the value of initial margin they have to pay
   */
  mapping(address => bytes32) initialMargin;
  /**
   * Map the contractAddress1 and 2 to the value of variation margin they have to pay
   * these value change every day
   */
  mapping(address => bytes32) variationMargin;

  modifier onlyMarketData
  {
    require(msg.sender == marketDataAddress);
    _;
  }

  modifier onlyChamber
  {
    require(msg.sender == compensationChamberAddress);
    _;
  }

  function asset(address _marketDataAddress, address _contractAddress1, address _contractAddress2, uint _settlementDate, string _nominal) public
  {
    marketDataAddress = _marketDataAddress;
    contractAddress1 = _contractAddress1; //floating leg
    contractAddress2 = _contractAddress2; //fixed leg
    tradeDate = block.timestamp;
    settlementDate = _settlementDate;
    nominal = _nominal;
    compensationChamberAddress = msg.sender;
    variationMargin[contractAddress1] = "0x0";
    variationMargin[contractAddress2] = "0x0";
  }

  function getIM(address contractAddress) public returns(bytes32)
  {
    return initialMargin[contractAddress];
  }
  // This function could only be executed by the asset holder's
  function getIM() public returns(bytes32)
  {
    return initialMargin[msg.sender];
  }

  function getClearingMemberContractAddressOfTheAsset() public onlyChamber returns(address[2])
  {
    return [contractAddress1, contractAddress2];
  }

  function setIM(string result) view onlyMarketData public
  {

     /*
    bytes32[] memory parts = stringToBytes32Array(result);

    clearingMember clearingMember1 = clearingMember(contractAddress1);
    clearingMember clearingMember2 = clearingMember(contractAddress2);

    initialMargin[contractAddress1] = parts[0];
    initialMargin[contractAddress2] = parts[1];

    clearingMember1.addAsset();
    clearingMember2.addAsset();*/
  }
}

contract clearingMember
{
  /**
   * Clearing member address
   * Compensation Chamber address
   * Array of addresses corresponding to the contracts that this clearing member have
   */
  address private memberAddress;
  address[] private assets;
  address private chamberAddress;

  /**
   * Events
   */
   event initialMargin(string price);
  /**
   * Add modifiers for this contract, one for the chamber and the other for the clearing memeber
   */
  modifier onlyChamber
  {
    require(msg.sender == chamberAddress);
    _;
  }

  modifier onlyMember
  {
    require(msg.sender == memberAddress);
    _;
  }

  function clearingMember(address _clearingMemberAddress) public
  {
    memberAddress = _clearingMemberAddress;
    chamberAddress = msg.sender;
  }

  function addAsset() public
  {
    assets.push(msg.sender);
  }
  function getAssets() public returns(address[])
  {
      return assets;
  }

  function getInitialMargin(address assetAddress) public returns(bytes32)
  {
    asset _asset = asset(assetAddress);
    return _asset.getIM();
  }
}

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
  event callbackRuning(string log);

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
  function getCurrencyExchange(string _base, string _secundary) public payable
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

  function getIMSwap(string _nominal, string _instrumentID) public payable
  {
    if (oraclize_getPrice("URL") > this.balance)
    {
      LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    }
    else
    {
      string memory URL = "json(http://83.231.14.17:3001/BOE/computeVaR/";
      string memory query1 = "0.95";
      string memory query2_4 = "/";
      //string memory query3 = _nominal;
      //string memory query5 = _instrumentID;
      string memory query6 = "/).*";

      string memory _query = strConcat(URL, query1, query2_4, _nominal, query2_4);
      string memory query = strConcat(_query, _instrumentID, query6);
      //LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
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
    callbackRuning("The callback is runing");
    uint functionNumber = queryIdToFunctionNumber[myid];

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

     address contractAddress = queryIdToContractAddressThatHaveCalledTheFunction[myid];
     vanillaSwap _vanillaSwap = vanillaSwap(contractAddress);
     _vanillaSwap.setIM(result);
    }
  }

}

contract vanillaSwap is asset
{

  function vanillaSwap(address _marketDataAddress, address _floatingLegMemberContractAddress, address _fixedLegMemberContractAddress, uint _settlementDate, string _nominal, string _instrumentID)asset(_marketDataAddress, _floatingLegMemberContractAddress, _fixedLegMemberContractAddress, _settlementDate, _nominal) public payable
  {
    MarketData marketDataContract = MarketData(_marketDataAddress);
    marketDataContract.getIMSwap.value(2 ether)(_nominal, _instrumentID);
  }

  function setVariationMargin() view onlyChamber public
  {
    MarketData marketDataContract = MarketData(marketDataAddress);
    //marketDataContract.getVMSwap.value(2 ether)(_nominal, _instrumentID);
  }

}