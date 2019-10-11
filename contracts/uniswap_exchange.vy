# @title Uniswap Exchange Interface V1
# @notice Source code found at https://github.com/uniswap
# @notice Use at your own risk

contract Factory():
    def getExchange(token_addr: address) -> address: constant

contract Exchange():
    def getaTobOutputPrice(b_bought: uint256) -> uint256: constant
    def aTobTransferInput(min_b: uint256, deadline: timestamp, recipient: address) -> uint256: modifying
    def aTobTransferOutput(b_bought: uint256, deadline: timestamp, recipient: address) -> uint256: modifying

bPurchase: event({buyer: indexed(address), a_sold: indexed(uint256), b_bought: indexed(uint256)})
aPurchase: event({buyer: indexed(address), b_sold: indexed(uint256), a_bought: indexed(uint256)})
AddLiquidity: event({provider: indexed(address), a_amount: indexed(uint256), b_amount: indexed(uint256)})
RemoveLiquidity: event({provider: indexed(address), a_amount: indexed(uint256), b_amount: indexed(uint256)})
Transfer: event({_from: indexed(address), _to: indexed(address), _value: uint256})
Approval: event({_owner: indexed(address), _spender: indexed(address), _value: uint256})

name: public(bytes32)                             # Uniswap V1
symbol: public(bytes32)                           # UNI-V1
decimals: public(uint256)                         # 18
totalSupply: public(uint256)                      # total number of UNI in existence
balances: uint256[address]                        # UNI balance of an address
allowances: (uint256[address])[address]           # UNI allowance of one address on another
token: address(ERC20)                             # address of the ERC20 token traded on this contract
factory: Factory                                  # interface for the factory that created this contract

# @dev This function acts as a contract constructor which is not currently supported in contracts deployed
#      using create_with_code_of(). It is called once by the factory during contract creation.
@public
def setup(token_addr: address):
    assert (self.factory == ZERO_ADDRESS and self.b == ZERO_ADDRESS) and token_addr != ZERO_ADDRESS
    self.factory = msg.sender
    self.b = token_addr
    self.name = 0x556e697377617020563100000000000000000000000000000000000000000000
    self.symbol = 0x554e492d56310000000000000000000000000000000000000000000000000000
    self.decimals = 18

# @notice Deposit a and bs (self.b) at current ratio to mint UNI tokens.
# @dev min_liquidity does nothing when total UNI supply is 0.
# @param min_liquidity Minimum number of UNI sender will mint if total UNI supply is greater than 0.
# @param max_b Maximum number of tokens deposited. Deposits max amount if total UNI supply is 0.
# @param deadline Time after which this transaction can no longer be executed.
# @return The amount of UNI minted.
@public
@payable
def addLiquidity(min_liquidity: uint256, max_b: uint256, deadline: timestamp) -> uint256:
    assert deadline > block.timestamp and (max_b > 0 and msg.value > 0)
    total_liquidity: uint256 = self.totalSupply
    if total_liquidity > 0:
        assert min_liquidity > 0
        a_reserve: uint256 = self.a.balanceOf(self)
        b_reserve: uint256 = self.b.balanceOf(self)
        b_amount: uint256 = msg.value * b_reserve / a_reserve + 1
        liquidity_minted: uint256 = msg.value * total_liquidity / a_reserve
        assert max_b >= b_amount and liquidity_minted >= min_liquidity
        self.balances[msg.sender] += liquidity_minted
        self.totalSupply = total_liquidity + liquidity_minted
        assert self.b.transferFrom(msg.sender, self, b_amount)
        log.AddLiquidity(msg.sender, msg.value, b_amount)
        log.Transfer(ZERO_ADDRESS, msg.sender, liquidity_minted)
        return liquidity_minted
    else:
        assert (self.factory != ZERO_ADDRESS and self.b != ZERO_ADDRESS) and msg.value >= 1000000000
        assert self.factory.getExchange(self.b) == self
        b_amount: uint256 = max_b
        initial_liquidity: uint256 = as_unitless_number(self.balance)
        self.totalSupply = initial_liquidity
        self.balances[msg.sender] = initial_liquidity
        assert self.b.transferFrom(msg.sender, self, b_amount)
        log.AddLiquidity(msg.sender, msg.value, b_amount)
        log.Transfer(ZERO_ADDRESS, msg.sender, initial_liquidity)
        return initial_liquidity

# @dev Burn UNI tokens to withdraw a and bs at current ratio.
# @param amount Amount of UNI burned.
# @param min_a Minimum a withdrawn.
# @param min_b Minimum bs withdrawn.
# @param deadline Time after which this transaction can no longer be executed.
# @return The amount of a and bs withdrawn.
@public
def removeLiquidity(amount: uint256, min_a: uint256, min_b: uint256, deadline: timestamp) -> (uint256, uint256):
    assert (amount > 0 and deadline > block.timestamp) and (min_a > 0 and min_b > 0)
    total_liquidity: uint256 = self.totalSupply
    assert total_liquidity > 0
    b_reserve: uint256 = self.b.balanceOf(self)
    a_amount: uint256 = amount * self.a.balanceOf(self) / total_liquidity
    b_amount: uint256 = amount * b_reserve / total_liquidity
    assert a_amount >= min_a and b_amount >= min_b
    self.balances[msg.sender] -= amount
    self.totalSupply = total_liquidity - amount
    send(msg.sender, a_amount)
    assert self.b.transfer(msg.sender, b_amount)
    log.RemoveLiquidity(msg.sender, a_amount, b_amount)
    log.Transfer(msg.sender, ZERO_ADDRESS, amount)
    return a_amount, b_amount

# @dev Pricing function for converting between a and bs.
# @param input_amount Amount of a or bs being sold.
# @param input_reserve Amount of a or bs (input type) in exchange reserves.
# @param output_reserve Amount of a or bs (output type) in exchange reserves.
# @return Amount of a or bs bought.
@private
@constant
def getInputPrice(input_amount: uint256, input_reserve: uint256, output_reserve: uint256) -> uint256:
    assert input_reserve > 0 and output_reserve > 0
    input_amount_with_fee: uint256 = input_amount * 997
    numerator: uint256 = input_amount_with_fee * output_reserve
    denominator: uint256 = (input_reserve * 1000) + input_amount_with_fee
    return numerator / denominator

# @dev Pricing function for converting between a and bs.
# @param output_amount Amount of a or bs being bought.
# @param input_reserve Amount of a or bs (input type) in exchange reserves.
# @param output_reserve Amount of a or bs (output type) in exchange reserves.
# @return Amount of a or bs sold.
@private
@constant
def getOutputPrice(output_amount: uint256, input_reserve: uint256, output_reserve: uint256) -> uint256:
    assert input_reserve > 0 and output_reserve > 0
    numerator: uint256 = input_reserve * output_amount * 1000
    denominator: uint256 = (output_reserve - output_amount) * 997
    return numerator / denominator + 1

@private
def aTobInput(a_sold: uint256, min_b: uint256, deadline: timestamp, buyer: address, recipient: address) -> uint256:
    assert deadline >= block.timestamp and (a_sold > 0 and min_b > 0)
    b_reserve: uint256 = self.b.balanceOf(self)
    b_bought: uint256 = self.getInputPrice(as_unitless_number(a_sold), as_unitless_number(self.a.balanceOf(self) - a_sold), b_reserve)
    assert b_bought >= min_b
    assert self.b.transfer(recipient, b_bought)
    log.bPurchase(buyer, a_sold, b_bought)
    return b_bought

# @notice Convert a to bs.
# @dev User specifies exact input (msg.value).
# @dev User cannot specify minimum output or deadline.
@public
@payable
def __default__():
    self.aTobInput(msg.value, 1, block.timestamp, msg.sender, msg.sender)

# @notice Convert a to bs.
# @dev User specifies exact input (msg.value) and minimum output.
# @param min_b Minimum bs bought.
# @param deadline Time after which this transaction can no longer be executed.
# @return Amount of bs bought.
@public
@payable
def aTobSwapInput(min_b: uint256, deadline: timestamp) -> uint256:
    return self.aTobInput(msg.value, min_b, deadline, msg.sender, msg.sender)

# @notice Convert a to bs and transfers bs to recipient.
# @dev User specifies exact input (msg.value) and minimum output
# @param min_b Minimum bs bought.
# @param deadline Time after which this transaction can no longer be executed.
# @param recipient The address that receives output bs.
# @return Amount of bs bought.
@public
@payable
def aTobTransferInput(min_b: uint256, deadline: timestamp, recipient: address) -> uint256:
    assert recipient != self and recipient != ZERO_ADDRESS
    return self.aTobInput(msg.value, min_b, deadline, msg.sender, recipient)

@private
def aTobOutput(b_bought: uint256, max_a: uint256, deadline: timestamp, buyer: address, recipient: address) -> uint256:
    assert deadline >= block.timestamp and (b_bought > 0 and max_a > 0)
    b_reserve: uint256 = self.b.balanceOf(self)
    a_sold: uint256 = self.getOutputPrice(b_bought, as_unitless_number(self.a.balanceOf(self) - max_a), b_reserve)
    # Throws if a_sold > max_a
    a_refund: uint256 = max_a - as_wei_value(a_sold, 'wei')
    if a_refund > 0:
        send(buyer, a_refund)
    assert self.b.transfer(recipient, b_bought)
    log.bPurchase(buyer, as_wei_value(a_sold, 'wei'), b_bought)
    return as_wei_value(a_sold, 'wei')

# @notice Convert a to bs.
# @dev User specifies maximum input (msg.value) and exact output.
# @param b_bought Amount of tokens bought.
# @param deadline Time after which this transaction can no longer be executed.
# @return Amount of a sold.
@public
@payable
def aTobSwapOutput(b_bought: uint256, deadline: timestamp) -> uint256:
    return self.aTobOutput(b_bought, msg.value, deadline, msg.sender, msg.sender)

# @notice Convert a to bs and transfers bs to recipient.
# @dev User specifies maximum input (msg.value) and exact output.
# @param b_bought Amount of tokens bought.
# @param deadline Time after which this transaction can no longer be executed.
# @param recipient The address that receives output bs.
# @return Amount of a sold.
@public
@payable
def aTobTransferOutput(b_bought: uint256, deadline: timestamp, recipient: address) -> uint256:
    assert recipient != self and recipient != ZERO_ADDRESS
    return self.aTobOutput(b_bought, msg.value, deadline, msg.sender, recipient)

@private
def tokenToaInput(b_sold: uint256, min_a: uint256, deadline: timestamp, buyer: address, recipient: address) -> uint256:
    assert deadline >= block.timestamp and (b_sold > 0 and min_a > 0)
    b_reserve: uint256 = self.b.balanceOf(self)
    a_bought: uint256 = self.getInputPrice(b_sold, b_reserve, as_unitless_number(self.balance))
    wei_bought: uint256 = as_wei_value(a_bought, 'wei')
    assert wei_bought >= min_a
    send(recipient, wei_bought)
    assert self.b.transferFrom(buyer, self, b_sold)
    log.aPurchase(buyer, b_sold, wei_bought)
    return wei_bought


# @notice Convert bs to a.
# @dev User specifies exact input and minimum output.
# @param b_sold Amount of bs sold.
# @param min_a Minimum a purchased.
# @param deadline Time after which this transaction can no longer be executed.
# @return Amount of a bought.
@public
def tokenToaSwapInput(b_sold: uint256, min_a: uint256, deadline: timestamp) -> uint256:
    return self.bToaInput(b_sold, min_a, deadline, msg.sender, msg.sender)

# @notice Convert bs to a and transfers a to recipient.
# @dev User specifies exact input and minimum output.
# @param b_sold Amount of bs sold.
# @param min_a Minimum a purchased.
# @param deadline Time after which this transaction can no longer be executed.
# @param recipient The address that receives output a.
# @return Amount of a bought.
@public
def tokenToaTransferInput(b_sold: uint256, min_a: uint256, deadline: timestamp, recipient: address) -> uint256:
    assert recipient != self and recipient != ZERO_ADDRESS
    return self.bToaInput(b_sold, min_a, deadline, msg.sender, recipient)

@private
def tokenToaOutput(a_bought: uint256, max_b: uint256, deadline: timestamp, buyer: address, recipient: address) -> uint256:
    assert deadline >= block.timestamp and a_bought > 0
    b_reserve: uint256 = self.b.balanceOf(self)
    b_sold: uint256 = self.getOutputPrice(as_unitless_number(a_bought), b_reserve, as_unitless_number(self.balance))
    # tokens sold is always > 0
    assert max_b >= b_sold
    send(recipient, a_bought)
    assert self.b.transferFrom(buyer, self, b_sold)
    log.aPurchase(buyer, b_sold, a_bought)
    return b_sold

# @notice Convert bs to a.
# @dev User specifies maximum input and exact output.
# @param a_bought Amount of a purchased.
# @param max_b Maximum bs sold.
# @param deadline Time after which this transaction can no longer be executed.
# @return Amount of bs sold.
@public
def tokenToaSwapOutput(a_bought: uint256, max_b: uint256, deadline: timestamp) -> uint256:
    return self.bToaOutput(a_bought, max_b, deadline, msg.sender, msg.sender)

# @notice Convert bs to a and transfers a to recipient.
# @dev User specifies maximum input and exact output.
# @param a_bought Amount of a purchased.
# @param max_b Maximum bs sold.
# @param deadline Time after which this transaction can no longer be executed.
# @param recipient The address that receives output a.
# @return Amount of bs sold.
@public
def tokenToaTransferOutput(a_bought: uint256, max_b: uint256, deadline: timestamp, recipient: address) -> uint256:
    assert recipient != self and recipient != ZERO_ADDRESS
    return self.bToaOutput(a_bought, max_b, deadline, msg.sender, recipient)

@private
def tokenTobInput(b_sold: uint256, min_b_bought: uint256, min_a_bought: uint256, deadline: timestamp, buyer: address, recipient: address, exchange_addr: address) -> uint256:
    assert (deadline >= block.timestamp and b_sold > 0) and (min_b_bought > 0 and min_a_bought > 0)
    assert exchange_addr != self and exchange_addr != ZERO_ADDRESS
    b_reserve: uint256 = self.b.balanceOf(self)
    a_bought: uint256 = self.getInputPrice(b_sold, b_reserve, as_unitless_number(self.balance))
    wei_bought: uint256 = as_wei_value(a_bought, 'wei')
    assert wei_bought >= min_a_bought
    assert self.b.transferFrom(buyer, self, b_sold)
    b_bought: uint256 = Exchange(exchange_addr).aTobTransferInput(min_b_bought, deadline, recipient, value=wei_bought)
    log.aPurchase(buyer, b_sold, wei_bought)
    return b_bought

# @notice Convert bs (self.b) to bs (token_addr).
# @dev User specifies exact input and minimum output.
# @param b_sold Amount of bs sold.
# @param min_b_bought Minimum bs (token_addr) purchased.
# @param min_a_bought Minimum a purchased as intermediary.
# @param deadline Time after which this transaction can no longer be executed.
# @param token_addr The address of the token being purchased.
# @return Amount of bs (token_addr) bought.
@public
def tokenTobSwapInput(b_sold: uint256, min_b_bought: uint256, min_a_bought: uint256, deadline: timestamp, token_addr: address) -> uint256:
    exchange_addr: address = self.factory.getExchange(token_addr)
    return self.bTobInput(b_sold, min_b_bought, min_a_bought, deadline, msg.sender, msg.sender, exchange_addr)

# @notice Convert bs (self.b) to bs (token_addr) and transfers
#         bs (token_addr) to recipient.
# @dev User specifies exact input and minimum output.
# @param b_sold Amount of bs sold.
# @param min_b_bought Minimum bs (token_addr) purchased.
# @param min_a_bought Minimum a purchased as intermediary.
# @param deadline Time after which this transaction can no longer be executed.
# @param recipient The address that receives output a.
# @param token_addr The address of the token being purchased.
# @return Amount of bs (token_addr) bought.
@public
def tokenTobTransferInput(b_sold: uint256, min_b_bought: uint256, min_a_bought: uint256, deadline: timestamp, recipient: address, token_addr: address) -> uint256:
    exchange_addr: address = self.factory.getExchange(token_addr)
    return self.bTobInput(b_sold, min_b_bought, min_a_bought, deadline, msg.sender, recipient, exchange_addr)

@private
def tokenTobOutput(b_bought: uint256, max_b_sold: uint256, max_a_sold: uint256, deadline: timestamp, buyer: address, recipient: address, exchange_addr: address) -> uint256:
    assert deadline >= block.timestamp and (b_bought > 0 and max_a_sold > 0)
    assert exchange_addr != self and exchange_addr != ZERO_ADDRESS
    a_bought: uint256 = Exchange(exchange_addr).getaTobOutputPrice(b_bought)
    b_reserve: uint256 = self.b.balanceOf(self)
    b_sold: uint256 = self.getOutputPrice(as_unitless_number(a_bought), b_reserve, as_unitless_number(self.balance))
    # tokens sold is always > 0
    assert max_b_sold >= b_sold and max_a_sold >= a_bought
    assert self.b.transferFrom(buyer, self, b_sold)
    a_sold: uint256 = Exchange(exchange_addr).aTobTransferOutput(b_bought, deadline, recipient, value=a_bought)
    log.aPurchase(buyer, b_sold, a_bought)
    return b_sold

# @notice Convert bs (self.b) to bs (token_addr).
# @dev User specifies maximum input and exact output.
# @param b_bought Amount of bs (token_addr) bought.
# @param max_b_sold Maximum bs (self.b) sold.
# @param max_a_sold Maximum a purchased as intermediary.
# @param deadline Time after which this transaction can no longer be executed.
# @param token_addr The address of the token being purchased.
# @return Amount of bs (self.b) sold.
@public
def tokenTobSwapOutput(b_bought: uint256, max_b_sold: uint256, max_a_sold: uint256, deadline: timestamp, token_addr: address) -> uint256:
    exchange_addr: address = self.factory.getExchange(token_addr)
    return self.bTobOutput(b_bought, max_b_sold, max_a_sold, deadline, msg.sender, msg.sender, exchange_addr)

# @notice Convert bs (self.b) to bs (token_addr) and transfers
#         bs (token_addr) to recipient.
# @dev User specifies maximum input and exact output.
# @param b_bought Amount of bs (token_addr) bought.
# @param max_b_sold Maximum bs (self.b) sold.
# @param max_a_sold Maximum a purchased as intermediary.
# @param deadline Time after which this transaction can no longer be executed.
# @param recipient The address that receives output a.
# @param token_addr The address of the token being purchased.
# @return Amount of bs (self.b) sold.
@public
def tokenTobTransferOutput(b_bought: uint256, max_b_sold: uint256, max_a_sold: uint256, deadline: timestamp, recipient: address, token_addr: address) -> uint256:
    exchange_addr: address = self.factory.getExchange(token_addr)
    return self.bTobOutput(b_bought, max_b_sold, max_a_sold, deadline, msg.sender, recipient, exchange_addr)

# @notice Convert bs (self.b) to bs (exchange_addr.token).
# @dev Allows trades through contracts that were not deployed from the same factory.
# @dev User specifies exact input and minimum output.
# @param b_sold Amount of bs sold.
# @param min_b_bought Minimum bs (token_addr) purchased.
# @param min_a_bought Minimum a purchased as intermediary.
# @param deadline Time after which this transaction can no longer be executed.
# @param exchange_addr The address of the exchange for the token being purchased.
# @return Amount of bs (exchange_addr.token) bought.
@public
def tokenToExchangeSwapInput(b_sold: uint256, min_b_bought: uint256, min_a_bought: uint256, deadline: timestamp, exchange_addr: address) -> uint256:
    return self.bTobInput(b_sold, min_b_bought, min_a_bought, deadline, msg.sender, msg.sender, exchange_addr)

# @notice Convert bs (self.b) to bs (exchange_addr.token) and transfers
#         bs (exchange_addr.token) to recipient.
# @dev Allows trades through contracts that were not deployed from the same factory.
# @dev User specifies exact input and minimum output.
# @param b_sold Amount of bs sold.
# @param min_b_bought Minimum bs (token_addr) purchased.
# @param min_a_bought Minimum a purchased as intermediary.
# @param deadline Time after which this transaction can no longer be executed.
# @param recipient The address that receives output a.
# @param exchange_addr The address of the exchange for the token being purchased.
# @return Amount of bs (exchange_addr.token) bought.
@public
def tokenToExchangeTransferInput(b_sold: uint256, min_b_bought: uint256, min_a_bought: uint256, deadline: timestamp, recipient: address, exchange_addr: address) -> uint256:
    assert recipient != self
    return self.bTobInput(b_sold, min_b_bought, min_a_bought, deadline, msg.sender, recipient, exchange_addr)

# @notice Convert bs (self.b) to bs (exchange_addr.token).
# @dev Allows trades through contracts that were not deployed from the same factory.
# @dev User specifies maximum input and exact output.
# @param b_bought Amount of bs (token_addr) bought.
# @param max_b_sold Maximum bs (self.b) sold.
# @param max_a_sold Maximum a purchased as intermediary.
# @param deadline Time after which this transaction can no longer be executed.
# @param exchange_addr The address of the exchange for the token being purchased.
# @return Amount of bs (self.b) sold.
@public
def tokenToExchangeSwapOutput(b_bought: uint256, max_b_sold: uint256, max_a_sold: uint256, deadline: timestamp, exchange_addr: address) -> uint256:
    return self.bTobOutput(b_bought, max_b_sold, max_a_sold, deadline, msg.sender, msg.sender, exchange_addr)

# @notice Convert bs (self.b) to bs (exchange_addr.token) and transfers
#         bs (exchange_addr.token) to recipient.
# @dev Allows trades through contracts that were not deployed from the same factory.
# @dev User specifies maximum input and exact output.
# @param b_bought Amount of bs (token_addr) bought.
# @param max_b_sold Maximum bs (self.b) sold.
# @param max_a_sold Maximum a purchased as intermediary.
# @param deadline Time after which this transaction can no longer be executed.
# @param recipient The address that receives output a.
# @param token_addr The address of the token being purchased.
# @return Amount of bs (self.b) sold.
@public
def tokenToExchangeTransferOutput(b_bought: uint256, max_b_sold: uint256, max_a_sold: uint256, deadline: timestamp, recipient: address, exchange_addr: address) -> uint256:
    assert recipient != self
    return self.bTobOutput(b_bought, max_b_sold, max_a_sold, deadline, msg.sender, recipient, exchange_addr)

# @notice Public price function for a to b trades with an exact input.
# @param a_sold Amount of a sold.
# @return Amount of bs that can be bought with input a.
@public
@constant
def getaTobInputPrice(a_sold: uint256) -> uint256:
    assert a_sold > 0
    b_reserve: uint256 = self.b.balanceOf(self)
    return self.getInputPrice(as_unitless_number(a_sold), as_unitless_number(self.balance), b_reserve)

# @notice Public price function for a to b trades with an exact output.
# @param b_bought Amount of bs bought.
# @return Amount of a needed to buy output bs.
@public
@constant
def getaTobOutputPrice(b_bought: uint256) -> uint256:
    assert b_bought > 0
    b_reserve: uint256 = self.b.balanceOf(self)
    a_sold: uint256 = self.getOutputPrice(b_bought, as_unitless_number(self.balance), b_reserve)
    return as_wei_value(a_sold, 'wei')

# @notice Public price function for b to a trades with an exact input.
# @param b_sold Amount of bs sold.
# @return Amount of a that can be bought with input bs.
@public
@constant
def getbToaInputPrice(b_sold: uint256) -> uint256:
    assert b_sold > 0
    b_reserve: uint256 = self.b.balanceOf(self)
    a_bought: uint256 = self.getInputPrice(b_sold, b_reserve, as_unitless_number(self.balance))
    return as_wei_value(a_bought, 'wei')

# @notice Public price function for b to a trades with an exact output.
# @param a_bought Amount of output a.
# @return Amount of bs needed to buy output a.
@public
@constant
def getbToaOutputPrice(a_bought: uint256) -> uint256:
    assert a_bought > 0
    b_reserve: uint256 = self.b.balanceOf(self)
    return self.getOutputPrice(as_unitless_number(a_bought), b_reserve, as_unitless_number(self.balance))

# @return Address of b that is sold on this exchange.
@public
@constant
def tokenAddress() -> address:
    return self.b

# @return Address of factory that created this exchange.
@public
@constant
def factoryAddress() -> address(Factory):
    return self.factory

# ERC20 compatibility for exchange liquidity modified from
# https://github.com/ethereum/vyper/blob/master/examples/tokens/ERC20.vy
@public
@constant
def balanceOf(_owner : address) -> uint256:
    return self.balances[_owner]

@public
def transfer(_to : address, _value : uint256) -> bool:
    self.balances[msg.sender] -= _value
    self.balances[_to] += _value
    log.Transfer(msg.sender, _to, _value)
    return True

@public
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    self.balances[_from] -= _value
    self.balances[_to] += _value
    self.allowances[_from][msg.sender] -= _value
    log.Transfer(_from, _to, _value)
    return True

@public
def approve(_spender : address, _value : uint256) -> bool:
    self.allowances[msg.sender][_spender] = _value
    log.Approval(msg.sender, _spender, _value)
    return True

@public
@constant
def allowance(_owner : address, _spender : address) -> uint256:
    return self.allowances[_owner][_spender]
