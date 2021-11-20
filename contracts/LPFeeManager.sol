// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

// import '@apeswapfinance/contracts/utils/Sweeper.sol';
import './interfaces/IApeRouter02.sol';
import './interfaces/IApeFactory.sol';
import './interfaces/IApePair.sol';
import './utils/Sweeper.sol';

/// @title LP fee manager
/// @author Apeswap.finance
/// @notice Swap LP token fees collected to different token
contract LPFeeManager is Sweeper {
    uint256 public MAX_SLIPPAGE_FACTOR = 100;

    address public adminAddress;
    address[] public possiblePaths;
    IApeRouter02 public router;
    IApeFactory public factory;

    uint256 public slippageFactor; //divided by 1000

    event ChangedPossiblePaths(address[] _paths);
    event LiquidityTokensSwapped(address[] _lpTokens, address _outputToken, address _to);
    event ChangedSlippage(uint256 previousSlippage, uint256 newSlippage);

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, 'not called by admin');
        _;
    }

    constructor(
        address[] memory _possiblePaths,
        address _router,
        address _factory,
        uint256 _slippageFactor,
        address _admin,
        address[] memory _lockedTokens,
        bool _allowNativeSweep
    ) public Sweeper(_lockedTokens, _allowNativeSweep) {
        possiblePaths = _possiblePaths;
        router = IApeRouter02(_router);
        factory = IApeFactory(_factory);
        slippageFactor = _slippageFactor;

        require(_admin != address(0), 'Admin is the zero address');
        adminAddress = _admin;
    }

    /// @notice Swap LP token fees collected to different token
    /// @param _lpTokens address list of LP tokens to swap to _outputToken
    /// @param _outputToken ERC20 token the LP tokens needs to be swapped to. Address(0) if you only want split LP tokens.
    /// @param _to address the tokens need to be transferred to.
    function swapLiquidityTokens(
        address[] memory _lpTokens,
        address _outputToken,
        address _to
    ) public onlyAdmin {
        for (uint256 i = 0; i < _lpTokens.length; i++) {
            _swapLiquidityToken(_lpTokens[i], _outputToken, _to);
        }
        emit LiquidityTokensSwapped(_lpTokens, _outputToken, _to);
    }

    /// @notice private function. Same as swapLiquidityTokens but for 1 LP token.
    /// @param _lpToken LP tokens to swap to _outputToken
    /// @param _outputToken ERC20 token the LP tokens needs to be swapped to. Address(0) if you only want to split LP tokens.
    /// @param _to address the tokens need to be transferred to.
    function _swapLiquidityToken(
        address _lpToken,
        address _outputToken,
        address _to
    ) private {
        address LPTokensToAddress = _outputToken == address(0) ? _to : address(this);

        IApePair pair = IApePair(_lpToken);
        uint256 balance = pair.balanceOf(address(this));
        pair.approve(address(router), balance);
        router.removeLiquidity(pair.token0(), pair.token1(), balance, 0, 0, LPTokensToAddress, block.timestamp + 600);

        if (_outputToken != address(0)) {
            _swapTokens(pair.token0(), _outputToken, _to);
            _swapTokens(pair.token1(), _outputToken, _to);
        }
    }

    /// @notice Swapping of tokens to _outputToken
    /// @param _token token to swap to _outputToken
    /// @param _outputToken ERC20 token the LP tokens needs to be swapped to
    /// @param _to address the tokens need to be transferred to.
    function _swapTokens(
        address _token,
        address _outputToken,
        address _to
    ) private {
        if (_token == _outputToken) {
            IERC20 token = IERC20(_token);
            uint256 balance = token.balanceOf(address(this));
            token.transfer(_to, balance);
            return;
        }

        if (factory.getPair(_token, _outputToken) == address(0)) {
            address[] memory path = new address[](3);
            for (uint256 i = 0; i < possiblePaths.length; i++) {
                address pathToken = possiblePaths[i];
                if (
                    _token != pathToken &&
                    _outputToken != pathToken &&
                    factory.getPair(_token, pathToken) != address(0) &&
                    factory.getPair(_outputToken, pathToken) != address(0)
                ) {
                    path[0] = _token;
                    path[1] = pathToken;
                    path[2] = _outputToken;
                    break;
                }
            }
            require(path[0] == _token, 'No path found');

            IERC20 token = IERC20(_token);
            uint256 amountIn = token.balanceOf(address(this));
            token.approve(address(router), amountIn);
            _safeSwap(amountIn, path, _to);
        } else {
            address[] memory path = new address[](2);
            path[0] = _token;
            path[1] = _outputToken;
            IERC20 token = IERC20(_token);
            uint256 amountIn = token.balanceOf(address(this));
            token.approve(address(router), amountIn);
            _safeSwap(amountIn, path, _to);
        }
    }

    /// @notice Actual swapping of tokens to _outputToken
    /// @param _amountIn amount of tokens to swap
    /// @param _path path to follow for swapping
    /// @param _to address the tokens need to be transferred to.
    function _safeSwap(
        uint256 _amountIn,
        address[] memory _path,
        address _to
    ) internal virtual {
        uint256[] memory amounts = router.getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length - 1];

        router.swapExactTokensForTokens(
            _amountIn,
            (amountOut * slippageFactor) / 1000,
            _path,
            _to,
            block.timestamp + 600
        );
    }

    /// @notice Add possible path
    /// @param _possiblePath new possible path
    function addPossiblePath(address _possiblePath) public onlyAdmin {
        possiblePaths.push(_possiblePath);
        emit ChangedPossiblePaths(possiblePaths);
    }

    /// @notice Change possible paths
    /// @param _possiblePaths New list of possible paths
    function changePossiblePaths(address[] memory _possiblePaths) public onlyAdmin {
        possiblePaths = _possiblePaths;
        emit ChangedPossiblePaths(possiblePaths);
    }

    /// @notice Change possible paths
    /// @param _slippage New slippage factor
    function changeSlippage(uint256 _slippage) public onlyAdmin {
        require(_slippage < MAX_SLIPPAGE_FACTOR, 'slippage too high');
        emit ChangedSlippage(slippageFactor, _slippage);
        slippageFactor = _slippage;
    }

    /// @notice Change admin
    /// @param _newAdmin New admin address
    function changeAdmin(address _newAdmin) public virtual onlyAdmin {
        require(_newAdmin != address(0), 'New admin is the zero address');
        emit OwnershipTransferred(adminAddress, _newAdmin);
        adminAddress = _newAdmin;
    }

    // /// @notice Sweep native coin
    // /// @param _to address the native coins should be transferred to
    // function sweepNative(address payable _to) public onlyOwner {
    //     _to.transfer(address(this).balance);
    // }
}
