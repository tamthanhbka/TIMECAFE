-- 1.Đưa ra danh sách loại  khách hàng Gold sinh nhật trong tháng 12 .

select * from KhachHang
where MaLKH in (select MaLKH from LoaiKH where TenLKH = 'Gold')
and month(NgaySinh) = 12;

-- 2.Đưa ra ten KH, loaiKH, SDT, DiaChi, DTL cua nhung  khách hàng có điểm tích lũy cao nhất. 

select TenKH, TenLKH, SDT, DiaChi, DTL from KhachHang, LoaiKH
where KhachHang.MaLKH = LoaiKH.MaLKH
and DTL >= all(select max(DTL) from KhachHang);

-- 3.Đưa ra bảng lương tháng của nhân viên cửa hàng ( Họ Tên, sdt, địa chỉ, lương), sắp xếp theo lương. 

select TenNV, SDT, DiaChi, sum(Luong) LuongThang from NhanVien, CLV, ChamCong
where ChamCong.MaCLV = CLV.MaCLV and NhanVien.MaNV = ChamCong.MaNV
group by NhanVien.MaNV
order by LuongThang desc;

-- 4.Đưa ra sản phẩm được mua nhiều nhất và có giá ban tren trung bình.

select TenSP, Gia from MENU
where Gia > (select avg(Gia) from MENU) 
and MaSP in (select MaSP from Orders 
             group by MaSP having sum(SoLuong) >= all(select sum(SoLuong) from Orders group by MaSP));

-- 5.Đưa ra  nhân viên xuất được nhiều hóa đơn nhất trong quý 2 năm 2021.

select TenNV, ChucVu, SDT, DiaChi, count(MaHD) ThanhTich from HoaDon, NhanVien
where HoaDon.MaNV = NhanVien.MaNV and Ngay > '2021-03-31' and Ngay < '2021-07-01'
group by NhanVien.MaNV having ThanhTich >= all(select count(MaHD) from HoaDon 
                                               where Ngay > '2021-03-31' and Ngay < '2021-07-01' group by MaNV);

-- 6.Đưa ra tỉ lệ quay lại trên 5 lần khách hàng trong quận Hai Bà Trưng.

select concat(format ( 
    ((select count(*) from (select KhachHang.MaKH from HoaDon, KhachHang 
                            where HoaDon.MaKH = KhachHang.MaKH and DiaChi like '%Hai Ba Trung%'
                            group by KhachHang.MaKH having count(MaHD) > 5) a
     ) /
     ( select count(*) from (select distinct KhachHang.MaKH from HoaDon, KhachHang
                             where HoaDon.MaKH = KhachHang.MaKH and DiaChi like '%Hai Ba Trung%') b
     )
    ) *100,2),'%') 'Ti Le Quay Lai';



-- 7.Đưa ra doanh thu của cửa hàng trong quý 1 năm 2021.(Lưu ý nếu khách hàng đó đến quán vào tháng sinh nhật của mình thì được giảm 15% hóa đơn.) 

select
    (
        (select sum(SoLuong * Gia) from MENU m, Orders o, HoaDon h
         where m.MaSP = o.MaSP and h.MaHD = o.MaHD and Ngay > '2020-12-31'and Ngay < '2021-04-01')
      - (select sum(SoLuong * Gia) * 0.15 from MENU m, Orders o, HoaDon h, KhachHang k
         where m.MaSP = o.MaSP and h.MaHD = o.MaHD and k.MaKH = h.MaKH 
         and Ngay > '2020-12-31' and Ngay < '2021-04-01'
         and month(Ngay) = month(NgaySinh)
        )
    ) as DoanhThu;

-- 8.Hãy đưa ra lịch sử giao dịch(ma KH, ten KH, SDT, dia chi,  Ngày, tổng thanh toán) của kkhách hàng ten 'Le Duc Son'.
-- drop function ThanhToan;

DELIMITER $$
create function ThanhToan (Ma_HD char(10))
returns int
DETERMINISTIC
BEGIN
declare tien int;
declare sinh date ;
declare ngayban date;
set tien = (select sum(SoLuong* Gia) from MENU, Orders where MENU.MaSP = Orders.MaSP and MaHD = Ma_HD);
set sinh = (select NgaySinh from KhachHang where MaKH = (select MaKH from HoaDon where MaHD = Ma_HD));
set ngayban = (select Ngay from HoaDon where MaHD = Ma_HD);
if month(sinh) = month(ngayban) then return (tien*0.75);
else return tien;
end if;
end $$
DELIMITER ;
select KhachHang.MaKH, TenKH, SDT, DiaChi, Ngay, ThanhToan(MaHD) from KhachHang, HoaDon
where KhachHang.MaKH = HoaDon.MaKH and TenKH = 'Le Duc Son';


-- 9.Đưa ra  thong tin sản phẩm  có lượng khách hang  trên 25 tuổi mua so voi tong so khach hang mua  > 47% (dua ra ti le cu the cua tung san pham)
-- drop function TILE;

delimiter $$
create function TILE (Ma_SP char(10))
returns float
DETERMINISTIC
BEGIN
declare soKH int;
declare soKH20 int;
declare tl float;
set soKH = (select count(MaKH) from Orders, HoaDon where HoaDon.MaHD = Orders.MaHD and MaSP = Ma_SP group by MaSP);
set soKH20 = (select count(MaKH) from Orders, HoaDon 
              where HoaDon.MaHD = Orders.MaHD and MaSP = Ma_SP 
              and MaKH in (select MaKH from KhachHang where year(curdate())-year(NgaySinh) > 25) 
              group by MaSP);
set tl = soKH20/soKH;
return tl;
end $$
delimiter ;
select MENU.*, concat(format(TILE(MaSP)*100,2),'%') 'Ti Le' from MENU where TILE(MaSP) > 0.47;

-- 10.Đưa ra độ yêu thích của các sản phẩm . Độ sản yêu thích được đánh  giá theo :
-- Không được yêu thích. 1,5%  (tinh tren tong so luong ban ra)
-- Được yêu thích.1,5%-2,95%  
-- Rất được yêu thích .trên 2,95%  
-- drop function DoYeuThich;

DELIMITER $$
create function DoYeuThich(Ten_SP varchar(255))
RETURNS varchar(50)
DETERMINISTIC
BEGIN
DECLARE Tong int;
DECLARE So int;
DECLARE TiLe float;
DECLARE YeuThich varchar(50);
select sum(SoLuong) into Tong from Orders;
select sum(SoLuong) into So from Orders where MaSP in (select MaSP from MENU where TenSP = Ten_SP);
set TiLe = So / Tong;
if TiLe < 0.015 then set YeuThich = "Khong duoc yeu thich";
elseif TiLe < 0.0295 then set YeuThich = "Duoc yeu thich";
else set YeuThich = "Rat duoc yeu thich";
end if;
return YeuThich;
end $$
DELIMITER ;
select TenSP, DoYeuThich(TenSP) from MENU group by TenSP;


