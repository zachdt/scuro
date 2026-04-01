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

contract BlackjackInitialDealVerifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 6530031235970850283118747997155835089086874891103647013468650848130351743056;
    uint256 constant alphay  = 14840637107003363705773497300093829614900578136420337723549337162204639783541;
    uint256 constant betax1  = 17247215301088280390075191565452565046635324041707079833590260512299647583385;
    uint256 constant betax2  = 2675519603970126215148881275746231032575992266401088432208313230986695905504;
    uint256 constant betay1  = 12427696260948033485744702735901884640050850503006522394213692126384974234633;
    uint256 constant betay2  = 4357533812966687642862183985066539845550557616324311925176426570981457287077;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 10064809317812203212929131777110853193164725360459914144092220771337606581499;
    uint256 constant deltax2 = 20479174965719947232020663446533362544464343316156319958340034226868673389729;
    uint256 constant deltay1 = 3924396094412016815955407735455330455644975828631814065680021135490278560476;
    uint256 constant deltay2 = 13344039327778014335309775685535016121072363323771706340495384741307412038901;

    
    uint256 constant IC0x = 6025381915827505074555781083841389353167017723123924683802891871529298197509;
    uint256 constant IC0y = 7475695344606221793960153521797897316718428830593802379751138655179409486541;
    
    uint256 constant IC1x = 10990971319079162817877651666425565776854269779008522291734549614337737249489;
    uint256 constant IC1y = 7502878641943247612173668165198795163449148681808775187799051975628697324872;
    
    uint256 constant IC2x = 15145978661127247440896004411683558264141752926196419490895500206411026129321;
    uint256 constant IC2y = 3709353288685012059985547440394656795861284668027404047630227074372373175970;
    
    uint256 constant IC3x = 11507881317790539721903527158455589329971678782958924291703453626401024723435;
    uint256 constant IC3y = 15946236692388737693508272665096303573709550044715944622487111109375037504702;
    
    uint256 constant IC4x = 10070071702887690883305050417102731111204780549285693679708375508389314657829;
    uint256 constant IC4y = 9967994470702933481957955418465504259050311563611182601476538603742045239232;
    
    uint256 constant IC5x = 21848028257806895048796276314214564525980316137021502804220636990766845062947;
    uint256 constant IC5y = 7773849073052738094512772249225193884303200864296431625444616136324112146497;
    
    uint256 constant IC6x = 20691279361143894268907777106281158218231865566254706412962515727935077890169;
    uint256 constant IC6y = 4768986703204398719144693711537931886497887937654437265555447654351011564076;
    
    uint256 constant IC7x = 2315642600547932099075541802113416858975935184778323293289646250932960633771;
    uint256 constant IC7y = 14515596161089189490238276462310514903332608531381138379966835369078708585406;
    
    uint256 constant IC8x = 485056978142701065235856341501272572289803878901400736032629865267855910194;
    uint256 constant IC8y = 7902172192893744997859006988868871384958605703111358030668217044722170346979;
    
    uint256 constant IC9x = 13207266500195067478353963229289661801038524282561524952167398384734223942659;
    uint256 constant IC9y = 19020240873008043789123270016438125829651952572064819356746751531518037130659;
    
    uint256 constant IC10x = 6534958695164997853819772821183469988489112250743880071019575115909477876701;
    uint256 constant IC10y = 166844161727218147304237477993445993946640410455695568977357381705545537131;
    
    uint256 constant IC11x = 15529149165745510661649549929928235463546713190082452463287113255247858150144;
    uint256 constant IC11y = 14179266702787742418796405736092262425298907183276294632367144823884278619757;
    
    uint256 constant IC12x = 10487852900670505033707395272338822977820302313565036326999539132624462515857;
    uint256 constant IC12y = 14183084421033140378134532882263969306114906460274748922191137747741732323595;
    
    uint256 constant IC13x = 16224062167063736124230007515633730497173946343434434749110209164950525615485;
    uint256 constant IC13y = 21103046017131744030563963991751393097801664367168963556630648912050927185826;
    
    uint256 constant IC14x = 20194805120080836759167891230555952382321054047471447804767168073068183563001;
    uint256 constant IC14y = 13993161494295121017360694261215386010151751382650488099308910770183057028381;
    
    uint256 constant IC15x = 19944740131419671639006276808041387403686068543003157157853820522041112519681;
    uint256 constant IC15y = 2452511835313463016753700922970999024693380263326554999333934624471813901150;
    
    uint256 constant IC16x = 1727396629240561694458322365725937697514178732507051217348505454871422912087;
    uint256 constant IC16y = 18639563601414045428368789682985081051705732153556227432901775250238008336703;
    
    uint256 constant IC17x = 3641844300836408192590511648234446355971268058729018632287746844927707963001;
    uint256 constant IC17y = 20915010369311596642036779570231690631155734304753782557079028869966705871316;
    
    uint256 constant IC18x = 12690183423467813375294741902589918549021419605259580204361889308017578940692;
    uint256 constant IC18y = 12003150138370128616742428380326334353517395045094325740410789164142329502104;
    
    uint256 constant IC19x = 17305387495551913459417502404615577888347048822288115645329573690370282912349;
    uint256 constant IC19y = 21501951660729199065385379568456951500110985572239307657527764240937605362273;
    
    uint256 constant IC20x = 10793065358269277718217989415721114567552306019447669952351332721091050226646;
    uint256 constant IC20y = 6242485098772393696304405739417644254656979796359546286682530268386035727783;
    
    uint256 constant IC21x = 8303311420646948900217649666371762840733285749184290529570402230245055555403;
    uint256 constant IC21y = 4080558614807255633037431364270127652968105153955944087844443418004684838772;
    
    uint256 constant IC22x = 18409790192079283941729462896784233964626225410581244468174673180503752351274;
    uint256 constant IC22y = 6062577002113066322476969009437855007937147759371186769882182405953506990922;
    
    uint256 constant IC23x = 5244332040479413260011705723370749292334686938153848767442869490466000539590;
    uint256 constant IC23y = 12810006065602162295898714285523349697203575569961851177391439978496284640975;
    
    uint256 constant IC24x = 10296939461072032163657653052578499464037373939952263645606348593838747949554;
    uint256 constant IC24y = 18999175171044735617102964308781993708917041914548066874935335119503559717066;
    
    uint256 constant IC25x = 7992185583332308332422025633244304472321155524673422639010005516377262124641;
    uint256 constant IC25y = 2423023813566901278580863548069090967139696932230591772078140117577926875835;
    
    uint256 constant IC26x = 7132500448579006955675009945464659163456380607141229641473245609094633295975;
    uint256 constant IC26y = 1853487032558778027522679076486691739483276960730959039448338479707379951410;
    
    uint256 constant IC27x = 18256490868421284944084806017086083321567019066905764709642398675483592481988;
    uint256 constant IC27y = 21594589952442267134621196298748570992343780066461009504221390132566003796576;
    
    uint256 constant IC28x = 17460940116907335069334690541624351112265081585546824799288841838021193037870;
    uint256 constant IC28y = 1691289606158611322933149583926016859598346449876769103514224442553601845926;
    
    uint256 constant IC29x = 5120192760244178871494359638098992951320858864033658913654040372664003543972;
    uint256 constant IC29y = 15195229643745576835270438403981119157035130471246788278737133379598056962497;
    
    uint256 constant IC30x = 11130583529031213343162193618245869909473381534957717877950827767225016191350;
    uint256 constant IC30y = 19074360730541569859995119264173074179882123565290679975704771742939762732530;
    
    uint256 constant IC31x = 14020937141155184384650556917537771650907206727870954807206144586820159983563;
    uint256 constant IC31y = 19310060496864183073245781720161600185367376729107692300951613653813025963745;
    
    uint256 constant IC32x = 14610647390908081382977794720005053677184576881506611303779134699202664922323;
    uint256 constant IC32y = 20156920329124922979640160736345803644803712298108749543719430042594564971559;
    
    uint256 constant IC33x = 16770341352987847722128914763075479561498572759426176201058036383166222337054;
    uint256 constant IC33y = 5960918586255205748189166582517123465716343503702858008927946600855006585843;
    
    uint256 constant IC34x = 3291006287370561798982354874615105734354448375730744563828624003120728847713;
    uint256 constant IC34y = 17828839053686113432863252550344346141449273546433351401771066274545235949711;
    
    uint256 constant IC35x = 5413454076935194116018022533050436770009173303405804084137571447166963435093;
    uint256 constant IC35y = 660627341234515349179914058027023112456171282872000884268280059170626019513;
    
    uint256 constant IC36x = 1089883640236164378988524405250437815224504949660479570059345940687526687901;
    uint256 constant IC36y = 7613207412006404881907181334477475635725397237373216758912889376102684259176;
    
    uint256 constant IC37x = 5121441786709846289899812648656147559330741005568008507383955450787304630286;
    uint256 constant IC37y = 9249370542093261074147065363747179641000930133524748211428876181028268696550;
    
    uint256 constant IC38x = 5128352107011130050151696163539537277965287051317776324181370510791723079728;
    uint256 constant IC38y = 19208493054638478031821237683805658394880547783042097898802454030523146304346;
    
    uint256 constant IC39x = 7934094019636174222795002219451521413252213011843432979756021761969743559577;
    uint256 constant IC39y = 1689866051393821390119401633894906617923969219995729085598502124685411214338;
    
    uint256 constant IC40x = 9438132252408544065797252727054349255188039564331245767478120248095807208804;
    uint256 constant IC40y = 19559657348395360563452411749471466920793166448374995650470893554983476067026;
    
    uint256 constant IC41x = 21501840802853764898371693170988704564802993912631597929635220485336935283493;
    uint256 constant IC41y = 15181043470247455474775060521218425437946553895593926964761630963792551893992;
    
    uint256 constant IC42x = 4614881322316578157051985391252247210972386799199986852543136874180780291975;
    uint256 constant IC42y = 13164844048894321907987801300400227392825205765821787049258512618781008015691;
    
    uint256 constant IC43x = 7887164093794541673129295091009921804515811439564336905571951918483289057527;
    uint256 constant IC43y = 9192042307785108366052846646841885235989482537556285698782170989567437689355;
    
    uint256 constant IC44x = 5309689189855891603360504372881011916330436657333398691399748298009685531033;
    uint256 constant IC44y = 18979794040355964300241760172450204830235417846427469397757923640584653033699;
    
    uint256 constant IC45x = 6489882733367709491337631518591607642941864787874915678249151514616168962093;
    uint256 constant IC45y = 19260380999602682188861072689884874544152442198528972294625246446867284716829;
    
    uint256 constant IC46x = 17634828012668644391272060832354926267254231408777574227074971597561789401267;
    uint256 constant IC46y = 5772762073897469209710300694862299205112770725483934023581688000797291860960;
    
    uint256 constant IC47x = 20514001599670412554061735271243312722588933087152097028661231369730960737302;
    uint256 constant IC47y = 9104840936100507387607592775445500360119764073076594737962873443805146984609;
    
    uint256 constant IC48x = 17290539851647961147983161343832864651673125357966355126377667792503299567633;
    uint256 constant IC48y = 11334417825774552880936855632448105382138847043433148650696657678144458145801;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[48] calldata _pubSignals) public view returns (bool) {
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
                
                g1_mulAccC(_pVk, IC13x, IC13y, calldataload(add(pubSignals, 384)))
                
                g1_mulAccC(_pVk, IC14x, IC14y, calldataload(add(pubSignals, 416)))
                
                g1_mulAccC(_pVk, IC15x, IC15y, calldataload(add(pubSignals, 448)))
                
                g1_mulAccC(_pVk, IC16x, IC16y, calldataload(add(pubSignals, 480)))
                
                g1_mulAccC(_pVk, IC17x, IC17y, calldataload(add(pubSignals, 512)))
                
                g1_mulAccC(_pVk, IC18x, IC18y, calldataload(add(pubSignals, 544)))
                
                g1_mulAccC(_pVk, IC19x, IC19y, calldataload(add(pubSignals, 576)))
                
                g1_mulAccC(_pVk, IC20x, IC20y, calldataload(add(pubSignals, 608)))
                
                g1_mulAccC(_pVk, IC21x, IC21y, calldataload(add(pubSignals, 640)))
                
                g1_mulAccC(_pVk, IC22x, IC22y, calldataload(add(pubSignals, 672)))
                
                g1_mulAccC(_pVk, IC23x, IC23y, calldataload(add(pubSignals, 704)))
                
                g1_mulAccC(_pVk, IC24x, IC24y, calldataload(add(pubSignals, 736)))
                
                g1_mulAccC(_pVk, IC25x, IC25y, calldataload(add(pubSignals, 768)))
                
                g1_mulAccC(_pVk, IC26x, IC26y, calldataload(add(pubSignals, 800)))
                
                g1_mulAccC(_pVk, IC27x, IC27y, calldataload(add(pubSignals, 832)))
                
                g1_mulAccC(_pVk, IC28x, IC28y, calldataload(add(pubSignals, 864)))
                
                g1_mulAccC(_pVk, IC29x, IC29y, calldataload(add(pubSignals, 896)))
                
                g1_mulAccC(_pVk, IC30x, IC30y, calldataload(add(pubSignals, 928)))
                
                g1_mulAccC(_pVk, IC31x, IC31y, calldataload(add(pubSignals, 960)))
                
                g1_mulAccC(_pVk, IC32x, IC32y, calldataload(add(pubSignals, 992)))
                
                g1_mulAccC(_pVk, IC33x, IC33y, calldataload(add(pubSignals, 1024)))
                
                g1_mulAccC(_pVk, IC34x, IC34y, calldataload(add(pubSignals, 1056)))
                
                g1_mulAccC(_pVk, IC35x, IC35y, calldataload(add(pubSignals, 1088)))
                
                g1_mulAccC(_pVk, IC36x, IC36y, calldataload(add(pubSignals, 1120)))
                
                g1_mulAccC(_pVk, IC37x, IC37y, calldataload(add(pubSignals, 1152)))
                
                g1_mulAccC(_pVk, IC38x, IC38y, calldataload(add(pubSignals, 1184)))
                
                g1_mulAccC(_pVk, IC39x, IC39y, calldataload(add(pubSignals, 1216)))
                
                g1_mulAccC(_pVk, IC40x, IC40y, calldataload(add(pubSignals, 1248)))
                
                g1_mulAccC(_pVk, IC41x, IC41y, calldataload(add(pubSignals, 1280)))
                
                g1_mulAccC(_pVk, IC42x, IC42y, calldataload(add(pubSignals, 1312)))
                
                g1_mulAccC(_pVk, IC43x, IC43y, calldataload(add(pubSignals, 1344)))
                
                g1_mulAccC(_pVk, IC44x, IC44y, calldataload(add(pubSignals, 1376)))
                
                g1_mulAccC(_pVk, IC45x, IC45y, calldataload(add(pubSignals, 1408)))
                
                g1_mulAccC(_pVk, IC46x, IC46y, calldataload(add(pubSignals, 1440)))
                
                g1_mulAccC(_pVk, IC47x, IC47y, calldataload(add(pubSignals, 1472)))
                
                g1_mulAccC(_pVk, IC48x, IC48y, calldataload(add(pubSignals, 1504)))
                

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
            
            checkField(calldataload(add(_pubSignals, 384)))
            
            checkField(calldataload(add(_pubSignals, 416)))
            
            checkField(calldataload(add(_pubSignals, 448)))
            
            checkField(calldataload(add(_pubSignals, 480)))
            
            checkField(calldataload(add(_pubSignals, 512)))
            
            checkField(calldataload(add(_pubSignals, 544)))
            
            checkField(calldataload(add(_pubSignals, 576)))
            
            checkField(calldataload(add(_pubSignals, 608)))
            
            checkField(calldataload(add(_pubSignals, 640)))
            
            checkField(calldataload(add(_pubSignals, 672)))
            
            checkField(calldataload(add(_pubSignals, 704)))
            
            checkField(calldataload(add(_pubSignals, 736)))
            
            checkField(calldataload(add(_pubSignals, 768)))
            
            checkField(calldataload(add(_pubSignals, 800)))
            
            checkField(calldataload(add(_pubSignals, 832)))
            
            checkField(calldataload(add(_pubSignals, 864)))
            
            checkField(calldataload(add(_pubSignals, 896)))
            
            checkField(calldataload(add(_pubSignals, 928)))
            
            checkField(calldataload(add(_pubSignals, 960)))
            
            checkField(calldataload(add(_pubSignals, 992)))
            
            checkField(calldataload(add(_pubSignals, 1024)))
            
            checkField(calldataload(add(_pubSignals, 1056)))
            
            checkField(calldataload(add(_pubSignals, 1088)))
            
            checkField(calldataload(add(_pubSignals, 1120)))
            
            checkField(calldataload(add(_pubSignals, 1152)))
            
            checkField(calldataload(add(_pubSignals, 1184)))
            
            checkField(calldataload(add(_pubSignals, 1216)))
            
            checkField(calldataload(add(_pubSignals, 1248)))
            
            checkField(calldataload(add(_pubSignals, 1280)))
            
            checkField(calldataload(add(_pubSignals, 1312)))
            
            checkField(calldataload(add(_pubSignals, 1344)))
            
            checkField(calldataload(add(_pubSignals, 1376)))
            
            checkField(calldataload(add(_pubSignals, 1408)))
            
            checkField(calldataload(add(_pubSignals, 1440)))
            
            checkField(calldataload(add(_pubSignals, 1472)))
            
            checkField(calldataload(add(_pubSignals, 1504)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
