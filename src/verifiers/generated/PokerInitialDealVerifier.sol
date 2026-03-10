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

contract PokerInitialDealVerifier {
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
    uint256 constant deltax1 = 17573855560102981384725471630120246006858785240668049053641875417853443423124;
    uint256 constant deltax2 = 17014772745926264118912000813559178959439614747605655859400182745183650442185;
    uint256 constant deltay1 = 763231389036143111909073870764670999297008846821504109260855459375550965966;
    uint256 constant deltay2 = 17918104477924967387837104374204442209633214783996467095418169495820658261312;

    
    uint256 constant IC0x = 1495829361117625697500653927604372792296940732549863737923939350458099295107;
    uint256 constant IC0y = 17032424151915273098118195908701556229590279388339365108619732266043301922424;
    
    uint256 constant IC1x = 11617826565462903513446292426004367239344690532494541432390058019632310209636;
    uint256 constant IC1y = 11910120263326167337310843709392620536840138229950200715586264391734252441172;
    
    uint256 constant IC2x = 6406557622209562729952175797705299722463150902544208558860569657784418542590;
    uint256 constant IC2y = 914151755040802313367577834185602165362306595845620947485563502900942274073;
    
    uint256 constant IC3x = 20381156578895831996799557448387033673415711098347531175090658998129906545466;
    uint256 constant IC3y = 9051113902767966010192092749222714741859638578857706557812788204657317426625;
    
    uint256 constant IC4x = 8437623899777605122676374837489358753949253793507257643082753910071746604850;
    uint256 constant IC4y = 12077176305267643185360359914359691711509187983264207821301759547406942884650;
    
    uint256 constant IC5x = 18489957826082728379129746574865424658457254622645937648456166919184717802244;
    uint256 constant IC5y = 14940981993052073507024452468669386688942735932215657233957667175090718083263;
    
    uint256 constant IC6x = 10827425195021810983811043915976392281904923029479218281717974322196156268355;
    uint256 constant IC6y = 1492523160387923143512936084298440219868034203704411701627243862115344064330;
    
    uint256 constant IC7x = 6863851117587788565815646239785461061543352899741596541001584841534287902183;
    uint256 constant IC7y = 14831619295692407920362218917722867324294848947770710502311926503071176797900;
    
    uint256 constant IC8x = 2709602435132627842321048726517062349478834298238046491978920646364515076700;
    uint256 constant IC8y = 10207042353925306629254314346681123999780396794281095385859953737863592264524;
    
    uint256 constant IC9x = 793644257648043039606510273813950861913961469758374605127686849723137054581;
    uint256 constant IC9y = 3143243190142088871340711817567880222061890774786767836719257777853722171166;
    
    uint256 constant IC10x = 15657175775314089450314163824677218147988978496835042498420483403280283309310;
    uint256 constant IC10y = 9084305758500638247587842251413200382005878390957354589382439201712408611572;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[10] calldata _pubSignals) public view returns (bool) {
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
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
