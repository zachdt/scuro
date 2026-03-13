// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract BlackjackShowdownVerifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 5357486762750547763894099768622049277094915015919213565139357978777662782304;
    uint256 constant alphay  = 10607267220437769230113375640453244228920782776283083462499005137686963394046;
    uint256 constant betax1  = 16389192845903415571457138014577476370724271859956167562610863588841263859796;
    uint256 constant betax2  = 17432211900774682868679786146042359414485306330191417978252039248886651004425;
    uint256 constant betay1  = 1616887969358894033906341518649972022736041914580546238549954870880344722022;
    uint256 constant betay2  = 7258877284214958503381038950105338251026862874227765945909767641467129035964;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 19522452887820339823527540539086337262706565645857707721200991832214039554499;
    uint256 constant deltax2 = 14655187520858052821552817510958608842257612057148252852377732425404124327492;
    uint256 constant deltay1 = 12056212322190034514616625836633815713292213110477799911603332557194435131454;
    uint256 constant deltay2 = 11083183148971497306416454259030085088812251564007243617948690755637001329658;

    
    uint256 constant IC0x = 12969054756949040219831821439545536581008872594888476451034269056215626963846;
    uint256 constant IC0y = 12803417373015735074578282692288568529082069299002901020478039650268810981436;
    
    uint256 constant IC1x = 7762787805360019856267574938305928513368140989910788686111174119572596401203;
    uint256 constant IC1y = 3178626927493530323123823429860363289754046609839526566533983740061869076073;
    
    uint256 constant IC2x = 14050828000179962406887345173211669770919194725555212511498280100133814201889;
    uint256 constant IC2y = 6184935643128271315866146049164707487914716746136112818576610102953762182637;
    
    uint256 constant IC3x = 5136820661388738165267917209471835202708132538842710173900765075982751376357;
    uint256 constant IC3y = 6383241374648093315161640927108859153648123826151738917410889434017575255520;
    
    uint256 constant IC4x = 10965192005608497546348311794447162649878153287907531689437230918708048943526;
    uint256 constant IC4y = 6450384461469701445495040852117619619075324818887343327072523477751708395751;
    
    uint256 constant IC5x = 19506516956136453706186018314597019642834896099586015848634479894308230153613;
    uint256 constant IC5y = 1127487098670898746692091061544030668482736848400944927455648238420951845986;
    
    uint256 constant IC6x = 18702507080502867843652563263525323587775901750362364208473863585259776289579;
    uint256 constant IC6y = 21407725563322383440650756975543167254100322840676148328060855891699901493990;
    
    uint256 constant IC7x = 2725622230124058107757609361671316190925019216140039877596907524818672170979;
    uint256 constant IC7y = 11034181365937170979725337146376310599906697347945665267796846935571488100039;
    
    uint256 constant IC8x = 10646789422781291430452847821661070791743481971701285230008157038604318098310;
    uint256 constant IC8y = 13383872512660639247196608926022076046203700381090616116702323070243979175479;
    
    uint256 constant IC9x = 5656224645162649021926904102304228294493667072916294544081257154688317290495;
    uint256 constant IC9y = 16898262539877690738801858908302925287499970363943991876137314230269283406221;
    
    uint256 constant IC10x = 19607041530866968554777674560029345214124613112221800040678731389836614962022;
    uint256 constant IC10y = 16523253090768690288697104456310688423784780619808513123394516606873086915098;
    
    uint256 constant IC11x = 9590139919965114141702184285868068174449889360974128418883264473956611950311;
    uint256 constant IC11y = 16869519555645185774130377431565191207686950449460117878699276653446593841939;
    
    uint256 constant IC12x = 7221748628527926882131112197164930981008244325492609244388629822587971284432;
    uint256 constant IC12y = 15002836401428397889603272733067723269424890461143441307869565103240555389721;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[12] calldata _pubSignals) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }
            
            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x
                
                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))
                
                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))
                
                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))
                
                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))
                
                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))
                
                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))
                
                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))
                
                g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))
                
                g1_mulAccC(_pVk, IC9x, IC9y, calldataload(add(pubSignals, 256)))
                
                g1_mulAccC(_pVk, IC10x, IC10y, calldataload(add(pubSignals, 288)))
                
                g1_mulAccC(_pVk, IC11x, IC11y, calldataload(add(pubSignals, 320)))
                
                g1_mulAccC(_pVk, IC12x, IC12y, calldataload(add(pubSignals, 352)))
                

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))


                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)


                let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F
            
            checkField(calldataload(add(_pubSignals, 0)))
            
            checkField(calldataload(add(_pubSignals, 32)))
            
            checkField(calldataload(add(_pubSignals, 64)))
            
            checkField(calldataload(add(_pubSignals, 96)))
            
            checkField(calldataload(add(_pubSignals, 128)))
            
            checkField(calldataload(add(_pubSignals, 160)))
            
            checkField(calldataload(add(_pubSignals, 192)))
            
            checkField(calldataload(add(_pubSignals, 224)))
            
            checkField(calldataload(add(_pubSignals, 256)))
            
            checkField(calldataload(add(_pubSignals, 288)))
            
            checkField(calldataload(add(_pubSignals, 320)))
            
            checkField(calldataload(add(_pubSignals, 352)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
